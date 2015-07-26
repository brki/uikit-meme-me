//
//  MemeList.swift
//  imagepicker
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import Foundation

// This is a slow and dirty way to persist the list of memes.
// For a production-ready app, a better storage mechanism would be used.

class MemeList {
	var list = [Meme]()
	static let dataFile = "memeList.data"
	static let sharedInstance = MemeList()

	var dataURL: NSURL {
		return documentDirectoryURL().URLByAppendingPathComponent(MemeList.dataFile)
	}

	subscript(id: String) -> Meme? {
		get {
			for meme in list {
				if meme.id == id {
					return meme
				}
			}
			return nil
		}
		set {
			if let value = newValue {
				for (i, meme) in enumerate(list) {
					if meme.id == value.id {
						list[i] = value
						return
					}
				}
				list.append(value)
			}
		}
	}

	init() {
		let dataUrl = dataURL
		if NSFileManager.defaultManager().fileExistsAtPath(dataURL.path!) {
			if let data = NSData(contentsOfURL: dataURL) {
				let decoder = NSKeyedUnarchiver(forReadingWithData: data)
				let count = decoder.decodeIntForKey("listCount")
				for i in 0 ..< count {
					if let memeInfo = decoder.decodeObject() as? Meme {
						list.append(memeInfo)
					}
				}
			}
		}
	}

	func persist() {
		let dataUrl = dataURL
		let data = NSMutableData()
		let coder = NSKeyedArchiver(forWritingWithMutableData: data)
		coder.encodeInteger(list.count, forKey: "listCount")
		for meme in list {
			coder.encodeObject(meme)
		}
		coder.finishEncoding()
		data.writeToURL(dataUrl, atomically: true)
	}

}
