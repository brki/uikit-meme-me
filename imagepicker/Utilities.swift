//
//  Utilities.swift
//  imagepicker
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import Foundation

func documentDirectoryURL() -> NSURL {
	let directories = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as! [NSURL]
	return directories.last!
}