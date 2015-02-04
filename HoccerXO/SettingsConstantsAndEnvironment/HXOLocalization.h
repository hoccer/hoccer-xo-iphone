//
//  HXOLocalization.h
//  HoccerXO
//
//  Created by Guido Lorenz on 03.02.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// When used in ObjC++ files (InvitationCodeViewController.mm) we need to
// declare C linkage on free functions to disable C++ name mangeling and avoid
// linker errors down the road.
#ifdef __cplusplus
# define HXO_OBJCPP_LINKAGE extern "C"
#else
# define HXO_OBJCPP_LINKAGE
#endif

HXO_OBJCPP_LINKAGE NSString* HXOAppName();
HXO_OBJCPP_LINKAGE NSString* HXOLocalizedString(NSString* key, NSString* comment, ...);
HXO_OBJCPP_LINKAGE NSAttributedString * HXOLocalizedStringWithLinks(NSString * key, NSString * comment);
