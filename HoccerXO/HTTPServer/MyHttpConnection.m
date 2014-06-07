//
//  MyHttpConnection.m
//  HoccerXO
//
//  Created by PM on 02.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MyHTTPConnection.h"
//#import "HTTPDynamicFileResponse.h"
#import "TypedHTTPDataResponse.h"
#import "TypedHTTPFileResponse.h"
#import "HTTPLogging.h"
#import "NSString+StringWithData.h"
#import "AppDelegate.h"
#import "HTTPServer.h"
#import "NSString+HTML.h"
#import "HXOUserDefaults.h"
#import "Contact.h"
#import "HXOBackend.h"
#import "HXOMessage.h"
#import "Attachment.h"
#import "UserProfile.h"
#import "Group.h"
#import "Delivery.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;


@implementation MyHTTPConnection

#ifdef WITH_WEBSERVER

- (NSString*)directoryListingOf:(NSString*)directoryPath {
    HTTPLogVerbose(@"%@[%p]: Serving up dynamic content", THIS_FILE, self);
    
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    
    if (!exists && !isDirectory) {
        return nil;
    }
    NSString * filePath = directoryPath;
    
    NSString *computerName = AppDelegate.instance.httpServer.publishedName;
    NSString *currentTime = [[NSDate date] description];
    
    NSString * header = [NSString stringWithFormat:@"Hoccer XO Server<br/>Host:%@ Time:%@<br/>", [computerName stringByEscapingForHTML],[currentTime stringByEscapingForHTML]];
    
    NSString * listing = @"";
    
    NSFileManager *fM = [NSFileManager defaultManager];
    NSError * error;
    NSArray * fileList = [fM contentsOfDirectoryAtPath:filePath error:&error];
    NSMutableArray *directoryList = [[NSMutableArray alloc] init];
    for(NSString *file in fileList) {
        NSString *path = [filePath stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        [fM fileExistsAtPath:path isDirectory:(&isDir)];
        if(isDir) {
            [directoryList addObject:file];
        }
        NSString * item = [NSString stringWithFormat:@"<a href='%@'>%@</a><br/>",[file stringByEscapingForHTML],[file stringByEscapingForHTML]];
        listing = [listing stringByAppendingString:item];
    }
    
    NSLog(@"%@", directoryList);
    
    NSString * responseString = [NSString stringWithFormat:@"<body>%@%@</body",header,listing];
    return responseString;
}

- (NSString*)chats {
    
    __block NSMutableArray * images = nil;
    __block NSMutableArray * nickNames = nil;
    __block NSMutableArray * clientsIds = nil;
    
    dispatch_sync(dispatch_get_main_queue(),^{
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName: [Contact entityName] inManagedObjectContext:AppDelegate.instance.mainObjectContext];
        [fetchRequest setEntity:entity];
        
        // Set the batch size to a suitable number.
        [fetchRequest setFetchBatchSize:20];
        
        // performance: do not include subentities
        //fetchRequest.includesSubentities = NO;
        
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"latestMessageTime" ascending: NO];
        NSSortDescriptor *sortDescriptor2 = [[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES];
        NSArray *sortDescriptors = @[sortDescriptor, sortDescriptor2];
        
        [fetchRequest setSortDescriptors:sortDescriptors];
        
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR relationshipState == 'kept' OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"];
        [fetchRequest setPredicate: filterPredicate];
        
        NSError *error;
        NSArray * contacts = [AppDelegate.instance.mainObjectContext executeFetchRequest:fetchRequest error:&error];
        if (error != nil) {
            NSLog(@"Error=%@",error);
        }
        // NSLog(@"found %d groups last updated before time %@", groups.count, lastUpdateTime);
        if (contacts == nil) {
            NSLog(@"Fetch request failed: %@", error);
            return;
        }
        images = [[NSMutableArray alloc]init];
        nickNames = [[NSMutableArray alloc]init];
        clientsIds = [[NSMutableArray alloc]init];
        
        for (Contact * contact in contacts) {
            //NSString * contactEntry = NS
            [nickNames addObject:contact.nickName];
            [clientsIds addObject:contact.clientId];
        }
    });
    if (nickNames == nil) {
        return nil;
    }
    NSString * result = @"<h1>Chats</h1><br/>";
    for (int i = 0; i < nickNames.count; ++i) {
        
        NSString * contactURL = [NSString stringWithFormat:@"/chat/%@",clientsIds[i]];
        NSString * avatarURL = [NSString stringWithFormat:@"/avatar/%@",clientsIds[i]];
        NSString * item = [NSString stringWithFormat:@"<a href='%@'><img src='%@' width='32' height='32' border='0' alt='avatar'/>%@</a><br/>\n",contactURL,avatarURL,[nickNames[i] stringByEscapingForHTML]];
        result = [result stringByAppendingString:item];
    }
    return result;
}


-(NSData*)avatarForClientId:(NSString*)clientId mimeType:(NSString**)mimeType {
    __block NSData * imageData = nil;
    dispatch_sync(dispatch_get_main_queue(),^{
        Contact * contact = [HXOBackend.instance getContactByClientId:clientId inContext:AppDelegate.instance.mainObjectContext];
        if (contact != nil) {
            if (contact.avatar != nil) {
                imageData = [contact.avatar copy];
                if (mimeType != nil) {
                    *mimeType = @"image/jpeg";
                }
            } else {
                NSString * avatarFileName = [contact.type isEqualToString: @"Group"] ?  @"avatar_default_group" : @"avatar_default_contact";
#ifdef NO_FIREFOX_WORKAROUND
                NSString *filePath = [[NSBundle mainBundle] pathForResource:avatarFileName ofType:@"png"];
                imageData = [NSData dataWithContentsOfFile:filePath];
                if (mimeType != nil) {
                    *mimeType = @"image/png";
                }
#else
                UIImage * avatarImage = [UIImage imageNamed: avatarFileName];
                imageData = UIImageJPEGRepresentation(avatarImage, 0.5);
                if (mimeType != nil) {
                    *mimeType = @"image/jpeg";
                }
#endif
            }
        } else {
            // return own avatar
            if ([[UserProfile sharedProfile].clientId isEqualToString:clientId]) {
                imageData = [[UserProfile sharedProfile] avatar];
                if (imageData == nil) {
                    UIImage * avatarImage = [UIImage imageNamed: @"avatar_default_contact"];
                    imageData = UIImageJPEGRepresentation(avatarImage, 0.5);
                    if (mimeType != nil) {
                        *mimeType = @"image/jpeg";
                    }
                }
            }
        }
    });
    return imageData;
}

-(HXOMessage*)getMessageById:(NSString*)messageId {
    NSError *error;
    NSDictionary * vars = @{ @"messageId" : messageId};
    NSFetchRequest *fetchRequest = [AppDelegate.instance.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByMessageId" substitutionVariables: vars];
    NSArray *messages = [AppDelegate.instance.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        return nil;
    }
    if (messages.count != 1) {
        if (messages.count > 1) {
            NSLog(@"ERROR: Database corrupted, duplicate messages with id %@ in database", messageId);
        }
        return nil;
    } else {
        return messages[0];
    }
}

-(NSData*)previewForMessageAttachment:(NSString*)messageId mimeType:(NSString**)mimeType {
    __block NSData * imageData = nil;
    dispatch_sync(dispatch_get_main_queue(),^{
        HXOMessage * message = [self getMessageById:messageId];
        if (message != nil) {
            imageData = [message.attachment.previewImageData copy];
            *mimeType = @"image/jpeg";
            
        }
     });
    return imageData;
}

-(NSString*)fileNameForMessageAttachment:(NSString*)messageId mimeType:(NSString**)mimeType {
    __block NSString * fileName = nil;
    dispatch_sync(dispatch_get_main_queue(),^{
        HXOMessage * message = [self getMessageById:messageId];
        if (message != nil) {
            fileName = [message.attachment.contentURL path];
            *mimeType = [message.attachment.mimeType copy];
            
        }
    });
    return fileName;
}

- (NSString*)chatWithContactId:(NSString*)clientId {
    
    __block NSMutableArray * myMessages = nil;
    __block NSString * partnerNick = nil;
    
    dispatch_sync(dispatch_get_main_queue(),^{
        Contact * partner = [HXOBackend.instance getContactByClientId:clientId inContext:AppDelegate.instance.mainObjectContext];
        if (partner != nil) {
            partnerNick = [partner.nickName copy];
            NSDictionary * vars = @{ @"contact" : partner };
            NSFetchRequest *fetchRequest = [AppDelegate.instance.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByContact" substitutionVariables: vars];
            
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeAccepted" ascending: YES];
            NSArray *sortDescriptors = @[sortDescriptor];
            
            [fetchRequest setSortDescriptors:sortDescriptors];
            
            NSError *error;
            NSArray * messages = [AppDelegate.instance.mainObjectContext executeFetchRequest:fetchRequest error:&error];
            if (error != nil) {
                NSLog(@"Error=%@",error);
            }
            // NSLog(@"found %d groups last updated before time %@", groups.count, lastUpdateTime);
            if (messages == nil) {
                NSLog(@"Fetch request failed: %@", error);
                return;
            }
            myMessages = [[NSMutableArray alloc]init];
            
            for (HXOMessage * message in messages) {
                NSMutableDictionary * myMessageDict = [[NSMutableDictionary alloc]init];
                myMessageDict[@"messageId"] = [message.messageId copy];
                if (message.body.length > 0) {
                    myMessageDict[@"body"] = [message.body copy];
                } else {
                    myMessageDict[@"body"] = @"";
                }
                myMessageDict[@"isOutgoing"] = [message.isOutgoing copy];
                if ([message.isOutgoing isEqualToNumber: @YES]) {
                    myMessageDict[@"author"] = [[[UserProfile sharedProfile] clientId] copy];
                    myMessageDict[@"authorNick"] = [[[UserProfile sharedProfile] nickName] copy];
                } else if ([partner isKindOfClass: [Group class]]) {
                    Contact * author = [(Delivery*)message.deliveries.anyObject sender];
                    if (author != nil) {
                        myMessageDict[@"author"] = [author.clientId copy];
                        myMessageDict[@"authorNick"] = [author.nickName copy];
                    } else {
                        myMessageDict[@"author"] = [partner.clientId copy];
                        myMessageDict[@"authorNick"] = [partner.nickName copy];
                    }
                } else {
                    myMessageDict[@"author"] = [partner.clientId copy];
                    myMessageDict[@"authorNick"] = [partner.nickName copy];
                }
                if (message.attachment != nil && message.attachment.contentURL != nil) {
                    myMessageDict[@"attachmentType"] = [message.attachment.mediaType copy];
                    myMessageDict[@"attachmentMimeType"] = [message.attachment.mimeType copy];
                    myMessageDict[@"attachmentAspect"] = @(message.attachment.aspectRatio);
                    //NSString * myURL = [message.attachment.contentURL path];
                    NSURL * myURL = message.attachment.contentURL;
                    // NSLog(@"url=%@, last=%@",myURL, [myURL lastPathComponent]);
                    myMessageDict[@"attachmentFile"] = [myURL lastPathComponent];
                }
                [myMessages addObject:myMessageDict];
            }
        }
    });
    if (myMessages == nil) {
        return nil;
    }
    NSString * result = [NSString stringWithFormat:@"<h1>Chat with %@</h1><br/>",[partnerNick stringByEscapingForHTML]];
    for (NSDictionary * message in myMessages) {
        
        NSString * authorURL = [NSString stringWithFormat:@"/chat/%@",message[@"author"]];
        NSString * authorAvatarURL = [NSString stringWithFormat:@"/avatar/%@",message[@"author"]];
        NSString * body = message[@"body"];
        NSString * direction = [message[@"isOutgoing"] boolValue] ? @"->" : @"<-";
        
        NSString * item = [NSString stringWithFormat:@"<div><a href='%@'><img src='%@' width='32' height='32' border='0' alt='avatar'/></a>%@%@<br/>\n",authorURL,authorAvatarURL,[direction stringByEscapingForHTML],[body stringByEscapingForHTML]];
        result = [result stringByAppendingString:item];
        
        item = [NSString stringWithFormat:@"<a href='%@'>%@</a><br/></div>\n",authorURL,[message[@"authorNick"] stringByEscapingForHTML]];
        result = [result stringByAppendingString:item];
        
        if (message[@"attachmentType"]!= nil) {
            NSString * attachmentPreviewURL = [NSString stringWithFormat:@"/attachmentpreview/%@",message[@"messageId"]];
            NSString * attachmentFileURL = [NSString stringWithFormat:@"/attachment/%@",message[@"messageId"]];
            float aspect = [message[@"attachmentAspect"] floatValue];
            int width = 256;
            int height = width / aspect;
            //NSLog(@"width=%d, height=%d",width, height);

            NSString * item = [NSString stringWithFormat:@"<div><a href='%@'><img src='%@' width='%d' height='%d' border='0' alt='preview'/><br/>%@ (%@)</a><br/></div><br/>\n",attachmentFileURL,attachmentPreviewURL,width, height, [message[@"attachmentType"] stringByEscapingForHTML], [message[@"attachmentMimeType"] stringByEscapingForHTML]];
            result = [result stringByAppendingString:item];
        }
        
    }
    return result;
}



- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	// Use HTTPConnection's filePathForURI method.
	// This method takes the given path (which comes directly from the HTTP request),
	// and converts it to a full path by combining it with the configured document root.
	//
	// It also does cool things for us like support for converting "/" to "/index.html",
	// and security restrictions (ensuring we don't serve documents outside configured document root folder).
	
    NSArray *pathComponents = [path pathComponents];
    
	NSString *documentRoot = [config documentRoot];

	NSString *filePath;
    if ([path isEqualToString:@"/"]) {
        filePath = documentRoot;
    } else {
        filePath = [self filePathForURI:path];
    }
	
	if (![filePath hasPrefix:documentRoot] && ![path isEqualToString:@"/"])
	{
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	//NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
    
    if ((pathComponents.count >= 2 && [pathComponents[1] isEqualToString:@"chats"]) || [path isEqualToString:@"/"]) {
        NSString * responseString = [self chats];
        if (responseString != nil) {
            responseString = [NSString stringWithFormat:@"<html xmlns='http://www.w3.org/1999/xhtml'>%@</html>",responseString];
            NSData * responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
            TypedHTTPDataResponse * response = [[TypedHTTPDataResponse alloc] initWithData:responseData];
            //response.mimeType = @"text/html";
            response.mimeType = @"text/xml";
            return response;
        }
        return nil;
    }
    if (pathComponents.count >= 3 && [pathComponents[1] isEqualToString:@"avatar"]) {
        NSString * mimeType;
        NSData * responseData = [self avatarForClientId:pathComponents[2] mimeType:&mimeType];
        if (responseData != nil) {
            TypedHTTPDataResponse * response = [[TypedHTTPDataResponse alloc] initWithData:responseData];
            response.mimeType = mimeType;
            return response;

        }
        return nil;
    }
    if (pathComponents.count >= 3 && [pathComponents[1] isEqualToString:@"attachmentpreview"]) {
        NSString * mimeType;
        NSData * responseData = [self previewForMessageAttachment:pathComponents[2] mimeType:&mimeType];
        if (responseData != nil) {
            TypedHTTPDataResponse * response = [[TypedHTTPDataResponse alloc] initWithData:responseData];
            response.mimeType = mimeType;
            return response;
            
        }
        return nil;
    }
    if (pathComponents.count >= 3 && [pathComponents[1] isEqualToString:@"chat"]) {
        NSString * responseString = [self chatWithContactId:pathComponents[2]];
        if (responseString != nil) {
            responseString = [NSString stringWithFormat:@"<html xmlns='http://www.w3.org/1999/xhtml'>%@</html>",responseString];
            NSData * responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
            TypedHTTPDataResponse * response = [[TypedHTTPDataResponse alloc] initWithData:responseData];
            //response.mimeType = @"text/html";
            response.mimeType = @"text/xml";
            return response;
        }
        return nil;
    }
    if (pathComponents.count >= 3 && [pathComponents[1] isEqualToString:@"attachment"]) {
        NSString * messageId = pathComponents[2];
        NSString * mimeType;
        NSString * filePath = [self fileNameForMessageAttachment:messageId mimeType:&mimeType];
        if (filePath != nil) {
        TypedHTTPFileResponse * response = [[TypedHTTPFileResponse alloc] initWithFilePath:filePath forConnection:self];
        response.mimeType = mimeType;
            return response;
        }
        return nil;
    }
#if 0
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (exists && isDirectory)
	{
        NSString * responseString = [self directoryListingOf:filePath];
        if (responseString != nil) {
            NSData * responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
            return [[HTTPDataResponse alloc] initWithData:responseData];
        }
        return nil;
	}
#endif
	return [super httpResponseForMethod:method URI:path];
}

- (BOOL)isPasswordProtected:(NSString *)path
{
	// We're only going to password protect the "secret" directory.
    //BOOL result = [path hasPrefix:@"/secret"];
	//HTTPLogTrace2(@"%@[%p]: isPasswordProtected(%@) - %@", THIS_FILE, self, path, (result ? @"YES" : @"NO"));	
	//return result;
    return YES;
}

- (BOOL)useDigestAccessAuthentication
{
	HTTPLogTrace();
	
	// Digest access authentication is the default setting.
	// Notice in Safari that when you're prompted for your password,
	// Safari tells you "Your login information will be sent securely."
	//
	// If you return NO in this method, the HTTP server will use
	// basic authentication. Try it and you'll see that Safari
	// will tell you "Your password will be sent unencrypted",
	// which is strongly discouraged.
	
	return YES;
}

- (NSString *)passwordForUser:(NSString *)username
{
	HTTPLogTrace();
	
	// You can do all kinds of cool stuff here.
	// For simplicity, we're not going to check the username, only the password.
	// return @"secret";
    return [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
}

- (NSString *)realm
{
	HTTPLogTrace();
	
	// Override me to provide a custom realm...
	// You can configure it for the entire server, or based on the current request
	
	return @"Hoccer XO WebServer on Client App";
}

#endif

@end
