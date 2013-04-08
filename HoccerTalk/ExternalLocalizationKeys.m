//
//  ExternalLocalizationKeys.m
//  HoccerTalk
//
//  Created by David Siegel on 08.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

// This file contains calls to NSLocalizedString(...) that would otherwise not appear in the code.
// That way I can rerun genstrings to update the english localization file without loosing these keys.

void APNLocalizationKeys() {
    (void)NSLocalizedString(@"apn_new_messages",    @"APN new messages");
    (void)NSLocalizedString(@"apn_one_new_message", @"You have a new message!");
}

