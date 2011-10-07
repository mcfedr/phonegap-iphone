/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 *  
 * Copyright (c) 2005-2011, Nitobi Software Inc.
 * Copyright (c) 2011, Matt Kane
 */

if (!PhoneGap.hasResource("filetransfer")) {
	PhoneGap.addResource("filetransfer");

/**
 * FileTransfer uploads a file to a remote server.
 */
FileTransfer = function() {}

/**
 * FileUploadResult
 */
FileUploadResult = function() {
    this.bytesSent = 0;
    this.responseCode = null;
    this.response = null;
}

/**
 * FileTransferError
 */
FileTransferError = function(errorCode) {
    this.code = errorCode || null;
}

FileTransferProgress = function(percent) {
	this.percent = percent;
}

FileTransferError.FILE_NOT_FOUND_ERR = 1;
FileTransferError.INVALID_URL_ERR = 2;
FileTransferError.CONNECTION_ERR = 3;

/**
* Given an absolute file path, uploads a file on the device to a remote server 
* using a multipart HTTP request.
* @param filePath {String}           Full path of the file on the device
* @param server {String}             URL of the server to receive the file
* @param successCallback (Function}  Callback to be invoked when upload has completed
* @param errorCallback {Function}    Callback to be invoked upon error
* @param options {FileUploadOptions} Optional parameters such as file name and mimetype           
*/
FileTransfer.prototype.upload = function(filePath, server, successCallback, errorCallback, options) {
	if(!options.params) {
		options.params = {};
	}
	options.filePath = filePath;
	options.server = server;
	if(!options.fileKey) {
		options.fileKey = 'file';
	}
	if(!options.fileName) {
		options.fileName = 'image.jpg';
	}
	if(!options.mimeType) {
		options.mimeType = 'image/jpeg';
	}
	
	if(options.progressCallback) {
		if(typeof options.progressCallback != "function") {
			console.log("FileTransfer Error: progressCallback is not a function");
	        return;
		}
		else {
			var callbackId = 'com.phonegap.filetransfer.progress' + PhoneGap.callbackId++;
			PhoneGap.callbacks[callbackId] = {success:options.progressCallback, fail:function() {}}
			options.progressCallback = callbackId;
		}
	}
	
	// successCallback required
	if (typeof successCallback != "function") {
        console.log("FileTransfer Error: successCallback is not a function");
        return;
    }


    // errorCallback optional
    if (errorCallback && (typeof errorCallback != "function")) {
        console.log("FileTransfer Error: errorCallback is not a function");
        return;
    }

	
	
    PhoneGap.exec(successCallback, errorCallback, 'com.phonegap.filetransfer', 'upload', [options]);
};

FileTransfer.prototype._castTransferError = function(pluginResult) {
	var fileError = new FileTransferError(pluginResult.message);
	//fileError.code = pluginResult.message;
	pluginResult.message = fileError;
	return pluginResult;
}

FileTransfer.prototype._castUploadResult = function(pluginResult) {
	var result = new FileUploadResult();
	result.bytesSent = pluginResult.message.bytesSent;
	result.responseCode = pluginResult.message.responseCode;
	result.response = decodeURIComponent(pluginResult.message.response);
	pluginResult.message = result;
	return pluginResult;
}

FileTransfer.prototype._castProgress = function(pluginResult) {
	var result = new FileTransferProgress(pluginResult.message.percent);
	pluginResult.message = result;
	return pluginResult;
}

/**
 * Options to customize the HTTP request used to upload files.
 * @param fileKey {String}   Name of file request parameter.
 * @param fileName {String}  Filename to be used by the server. Defaults to image.jpg.
 * @param mimeType {String}  Mimetype of the uploaded file. Defaults to image/jpeg.
 * @param params {Object}    Object with key: value params to send to the server.
 */
FileUploadOptions = function(fileKey, fileName, mimeType, params, progressCallback) {
    this.fileKey = fileKey || null;
    this.fileName = fileName || null;
    this.mimeType = mimeType || null;
    this.params = params || null;
	this.progressCallback = progressCallback || null;
}


PhoneGap.addConstructor(function() {
    if (typeof navigator.fileTransfer == "undefined") navigator.fileTransfer = new FileTransfer();
});
};
