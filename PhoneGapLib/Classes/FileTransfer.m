/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 * 
 * Copyright (c) 2005-2011, Nitobi Software Inc.
 * Copyright (c) 2011, Matt Kane
 * Copyright (c) 2011, IBM Corporation
 */

#import "FileTransfer.h"
#import "ASIFormDataRequest.h"

@implementation PGFileTransfer

- (void) upload:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString* fileKey = (NSString*)[options objectForKey:@"fileKey"];
    //NSString* fileName = (NSString*)[options objectForKey:@"fileName"];
    //NSString* mimeType = (NSString*)[options objectForKey:@"mimeType"];
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)[options objectForKey:@"params"]];
    NSString* filePath = (NSString*)[options objectForKey:@"filePath"];
    NSString* server = (NSString*)[options objectForKey:@"server"];
    NSString* progressCallback = (NSString*)[options objectForKey:@"progressCallback"];
    
    PluginResult* result = nil;
    FileTransferError errorCode = 0;
    
    
    NSURL* file;
    //NSData *fileData = nil;
    
    if ([filePath hasPrefix:@"/"]) {
        file = [NSURL fileURLWithPath:filePath];
    } else {
        file = [NSURL URLWithString:filePath];
    }
    
    NSURL *url = [NSURL URLWithString:server];
    
    
    if (!url) {
        errorCode = INVALID_URL_ERR;
        NSLog(@"File Transfer Error: Invalid server URL");
    } else if(![file isFileURL]) {
        errorCode = FILE_NOT_FOUND_ERR;
        NSLog(@"File Transfer Error: Invalid file path or URL");
    } else {
        // check that file is valid
        NSFileManager* fileMgr = [[NSFileManager alloc] init];
        BOOL bIsDirectory = NO;
        BOOL bExists = [fileMgr fileExistsAtPath:[file path] isDirectory:&bIsDirectory];
        if (!bExists || bIsDirectory) {
            errorCode = FILE_NOT_FOUND_ERR;
        } else {
            // file exists, make sure we can get the data
            /*fileData = [NSData dataWithContentsOfURL:file];
             
             if(!fileData) {
             errorCode =  FILE_NOT_FOUND_ERR;
             NSLog(@"File Transfer Error: Could not read file data");
             }*/
        }
        [fileMgr release];
    }
    
    if(errorCode > 0) {
        result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsInt: INVALID_URL_ERR cast: @"navigator.fileTransfer._castTransferError"];
        [self writeJavascript:[result toErrorCallbackString:callbackId]];
        return;
    }
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setRequestMethod:@"POST"];
    
    
    if([params objectForKey:@"__cookie"]) {
        [request setUseCookiePersistence:NO];
        [request setRequestCookies:[params objectForKey:@"__cookie"]];
        [params removeObjectForKey:@"__cookie"];
    }
    
    [request addRequestHeader:@"X-Requested-With" value:@"XMLHttpRequest"];
    NSString* userAgent = [[self.webView request] valueForHTTPHeaderField:@"User-agent"];
	if(userAgent) {
		[request addRequestHeader:@"User-agent" value:userAgent];
	}
    
    NSEnumerator *enumerator = [params keyEnumerator];
	id key;
	id val;
	
	while ((key = [enumerator nextObject])) {
        val = [params objectForKey:key];
		if(!val || val == [NSNull null]) {
			continue;	
		}
		// if it responds to stringValue selector (eg NSNumber) get the NSString
		if ([val respondsToSelector:@selector(stringValue)]) {
			val = [val stringValue];
		}
		// finally, check whether it is a NSString (for dataUsingEncoding selector below)
		if (![val isKindOfClass:[NSString class]]) {
			continue;
		}
        [request setPostValue:val forKey:key];
    }
    
    [request setFile:[file path] forKey:fileKey];
    
    
    FileTransferDelegate* delegate = [[FileTransferDelegate alloc] init];
	delegate.command = self;
    delegate.callbackId = callbackId;
    delegate.progressCallback = progressCallback;
    
    request.timeOutSeconds = 60;
    [request setDelegate:delegate];
    request.showAccurateProgress = YES;
    [request setUploadProgressDelegate:delegate];
    
    [request startAsynchronous];
}

@end


@implementation FileTransferDelegate

@synthesize callbackId, responseData, command, bytesWritten, progressCallback;


- (id) init
{
    if ((self = [super init])) {
        self.bytesWritten = 0;
		self.responseData = [NSMutableData data];
    }
    return self;
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
    if(self.progressCallback != nil) {
        NSMutableDictionary* uploadResult = [NSMutableDictionary dictionaryWithCapacity:1];
        [uploadResult setObject:[NSNumber numberWithFloat:(100)] forKey:@"percent"];
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsDictionary: uploadResult cast: @"navigator.fileTransfer._castProgress"];
        [command writeJavascript:[result toSuccessCallbackString: self.progressCallback]];
        self.progressCallback = nil;
    }
    
    // Use when fetching text data
    NSString *responseString = [request responseString];
    
    NSMutableDictionary* uploadResult = [NSMutableDictionary dictionaryWithCapacity:3];
    [uploadResult setObject:[responseString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey: @"response"];
    [uploadResult setObject:[NSNumber numberWithInt: self.bytesWritten] forKey:@"bytesSent"];
    [uploadResult setObject:[NSNumber numberWithInt: request.responseStatusCode] forKey: @"responseCode"];
    PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsDictionary: uploadResult cast: @"navigator.fileTransfer._castUploadResult"];
    [command writeJavascript:[result toSuccessCallbackString: callbackId]];
    [self autorelease];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    
    if(self.progressCallback != nil) {
        NSMutableDictionary* uploadResult = [NSMutableDictionary dictionaryWithCapacity:1];
        [uploadResult setObject:[NSNumber numberWithFloat:(0)] forKey:@"percent"];
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsDictionary: uploadResult cast: @"navigator.fileTransfer._castProgress"];
        [command writeJavascript:[result toSuccessCallbackString: self.progressCallback]];
        self.progressCallback = nil;
    }
    
    NSError *error = [request error];
    PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsInt: CONNECTION_ERR cast: @"navigator.fileTransfer._castTransferError"];
    NSLog(@"File Transfer Error: %@", [error localizedDescription]);
    [command writeJavascript:[result toErrorCallbackString: callbackId]];
    [self autorelease];
}

- (void)setProgress:(float)newProgress {
    if(self.progressCallback != nil) {
        NSMutableDictionary* uploadResult = [NSMutableDictionary dictionaryWithCapacity:1];
        [uploadResult setObject:[NSNumber numberWithFloat:(newProgress * 100)] forKey:@"percent"];
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsDictionary: uploadResult cast: @"navigator.fileTransfer._castProgress"];
        result.keepCallback = [NSNumber numberWithBool:YES];
        [command writeJavascript:[result toSuccessCallbackString: self.progressCallback]];
    }
}

- (void)request:(ASIHTTPRequest *)request didSendBytes:(long long)bytes {
    self.bytesWritten += bytes;
}

- (void) dealloc
{
    [callbackId release];
	[responseData release];
	[command release];
    [progressCallback release];
    [super dealloc];
}

@end;
