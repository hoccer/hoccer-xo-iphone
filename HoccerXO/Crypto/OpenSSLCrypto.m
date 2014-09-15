//
//  OpenSSLCrypto.m
//  HoccerXO
//
//  Created by PM on 13.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "OpenSSLCrypto.h"
#import "fmemopen.h"

#import "AppDelegate.h"

#include <openssl/aes.h>
#include <openssl/des.h>
#include <openssl/err.h>
#include <openssl/hmac.h>
#include <openssl/pem.h>
#include <openssl/rand.h>

@implementation OpenSSLCrypto

RSA *create_rsa_key(const int bits)
{
    RSA    *rsa = RSA_new();
    BIGNUM *f4  = BN_new();
    BN_set_word(f4, RSA_F4);
    
    /* generate private and public keys */
    NSLog(@"Creating RSA key with %d bits\n\n\n", bits);
    if (!RSA_generate_key_ex(rsa, bits, f4, NULL)) {
        NSLog(@"create_rsa_key failed (RSA_generate_key_ex): %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto err_out;
    }
    
    return rsa;
    
err_out:
    RSA_free(rsa);
    return NULL;
}

int save_rsa_keypair(const char *const pubfilename, const char *const privfilename, RSA *const rsa)
{
    int   err         = 0;
    FILE *fp = NULL;
    
    NSLog(@"Saving RSA keys to: pub='%s' priv='%s'", pubfilename, privfilename);
    NSLog(@"Saving host RSA n=%s\n", BN_bn2hex(rsa->n));
    NSLog(@"Saving host RSA e=%s\n", BN_bn2hex(rsa->e));
    NSLog(@"Saving host RSA d=%s\n", BN_bn2hex(rsa->d));
    NSLog(@"Saving host RSA p=%s\n", BN_bn2hex(rsa->p));
    NSLog(@"Saving host RSA q=%s\n", BN_bn2hex(rsa->q));
    
    /* rewrite using PEM_write_PKCS8PrivateKey */
    
    fp = fopen(pubfilename, "wb");
    if (fp == 0) {
        NSLog(@"Couldn't open public key file %s for writing\n", pubfilename);
        goto out_err;
    }
    
    err = PEM_write_RSA_PUBKEY(fp, rsa) == 0 ? 1 : 0;
    
    if (err) {
        NSLog(@"Write failed for %s\n", pubfilename);
        goto out_err;
    }
    if ((err = fclose(fp))) {
        NSLog(@"Error closing file\n");
        goto out_err;
    }
    fclose(fp);
    
    fp = fopen(privfilename, "wb" /* mode */);
    if (fp == 0) {
        NSLog(@"Couldn't open private key file %s for writing\n", privfilename);
    }
    
    err = PEM_write_RSAPrivateKey(fp, rsa, NULL, NULL, 0, NULL, NULL) == 0 ? 1 : 0;
    if (err) {
        NSLog(@"Write failed for %s\n", privfilename);
        goto out_err;
    }
out_err:
    if (fclose(fp)) {
        NSLog(@"Error closing file\n");
    };
    
    if (err) {
        if (unlink(privfilename)) { /* add error check */
            NSLog(@"Could not delete file %s\n", privfilename);
        }
        if (unlink(pubfilename)) { /* add error check */
            NSLog(@"Could not delete file %s\n", pubfilename);
        }
    }
    return err;
}

int save_rsa_keypair_to_fp(FILE * pubfp, FILE * privfp, RSA *const rsa)
{
    int   err         = 0;
#if 0
    NSLog(@"Saving host RSA n=%s\n", BN_bn2hex(rsa->n));
    NSLog(@"Saving host RSA e=%s\n", BN_bn2hex(rsa->e));
    NSLog(@"Saving host RSA d=%s\n", BN_bn2hex(rsa->d));
    NSLog(@"Saving host RSA p=%s\n", BN_bn2hex(rsa->p));
    NSLog(@"Saving host RSA q=%s\n", BN_bn2hex(rsa->q));
#endif
    
    err = PEM_write_RSA_PUBKEY(pubfp, rsa) == 0 ? 1 : 0;
    
    if (err) {
        NSLog(@"Write failed for pubfp");
        goto out_err;
    }
    
    err = PEM_write_RSAPrivateKey(privfp, rsa, NULL, NULL, 0, NULL, NULL) == 0 ? 1 : 0;
    if (err) {
        NSLog(@"Write failed for privfp");
        goto out_err;
    }
out_err:
    return err;
}

+(NSString*)getPathForFile:(NSString*)newFileName {
    NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myDocDir = [appDocDir path];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: newFileName];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return [myLocalURL path];
}


+ (BOOL)makeRSAKeyPairPEMWithSize:(int)bits withPublicKey:(NSString**)pubkey withPrivateKey:(NSString**)privkey {
    
    *pubkey = nil;
    *privkey = nil;
    int err = 0;
    NSMutableData * privData = [NSMutableData dataWithLength:200000];
    NSMutableData * pubData = [NSMutableData dataWithLength:200000];
    FILE * privfp = fmemopen([privData mutableBytes], [privData length], "rw");
    FILE * pubfp = fmemopen([pubData mutableBytes], [pubData length], "rw");

    NSString * privpath = [OpenSSLCrypto getPathForFile:@"priv.pem"];
    NSString * pubpath = [OpenSSLCrypto getPathForFile:@"pub.pem"];
    NSLog(@"privpath=%@",privpath);
    NSLog(@"pubpath=%@",pubpath);
    
    RSA * rsa = create_rsa_key(bits);
    if (!rsa) {
        NSLog(@"makeRSAKeyPairPEMWithSize : failed to create key");
        goto cleanup2;
    }
#if 0
    err = save_rsa_keypair([pubpath cStringUsingEncoding:NSUTF8StringEncoding], [privpath cStringUsingEncoding:NSUTF8StringEncoding], rsa);
    if (err != 0) {
        NSLog(@"makeRSAKeyPairPEMWithSize file saving err=%d",err);
    }
#endif
    err = save_rsa_keypair_to_fp(pubfp, privfp, rsa);
    if (err != 0) {
        NSLog(@"makeRSAKeyPairPEMWithSize saving err=%d",err);
        goto cleanup;
    }
    
    long publen = ftell(pubfp);
    long privlen = ftell(privfp);
    
    if (publen <= 0) {
        NSLog(@"makeRSAKeyPairPEMWithSize: bad publen %ld", publen);
        goto cleanup;
    }
    if (privlen <= 0) {
        NSLog(@"makeRSAKeyPairPEMWithSize: bad privlen %ld", privlen);
        goto cleanup;
    }
    
    [privData setLength:privlen];
    [pubData setLength:publen];
    
    *pubkey = [NSString stringWithUTF8String:[pubData bytes]];
    *privkey = [NSString stringWithUTF8String:[privData bytes]];

    //NSLog(@"makeRSAKeyPairPEMWithSize: privkey\n=%@\n", *privkey);
    //NSLog(@"makeRSAKeyPairPEMWithSize: pubkey=\n%@\n", *pubkey);
cleanup:
    RSA_free(rsa);
cleanup2:
    fclose(pubfp);
    fclose(privfp);
    
    return (privkey != nil && pubkey != nil);
}

@end
