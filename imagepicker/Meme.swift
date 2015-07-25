//
//  Meme.swift
//  imagepicker
//
//  Created by Brian on 18/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import Foundation
import UIKit

struct Meme {
	var text1: String
	var text2: String
	var id: String?

	enum ResourceType: String {
		case Source = "source"
		case Meme = "meme"
		case MemeThumbnail = "meme-thumbnail"
		case Texts = "texts"
	}

	var resourceURL: NSURL? {
		if let id = id {
			let bundleURL = NSBundle.mainBundle().bundleURL
			let resourceURL = bundleURL.URLByAppendingPathComponent("Documents/" + id, isDirectory: true)
			var error: NSError?
			// Try to create the directory, if it doesn't already exist:
			NSFileManager.defaultManager().createDirectoryAtURL(resourceURL, withIntermediateDirectories: true, attributes: nil, error: &error)
			if let err = error {
				println("Unable to create directory for resource contents. Error: \(err.localizedDescription)")
			} else {
				return resourceURL
			}
		}
		return nil
	}

	// TODO: when an image is picked, save it in the app's main bundle

	func image(type: ResourceType) -> UIImage?
	{
		if let name = imageNameForType(type) {
			return UIImage(named: name)
		}
		return nil
	}

	func imageNameForType(type: ResourceType) -> String? {
		if let id = id {
			return id + "-" + type.rawValue + ".png"
		}
		println("id is currently nil")
		return nil
	}

	func saveImage(image: UIImage, ofType type: ResourceType, withBaseUrl baseUrl: NSURL, asThumbnail: Bool = false) -> Bool {
		if let name = imageNameForType(type) {
			if asThumbnail {
				// TODO: convert to thumbnail
			}
			let data = UIImagePNGRepresentation(image)
			let url = baseUrl.URLByAppendingPathComponent(name, isDirectory: false)
			if data.writeToURL(url, atomically: true) {
				return true
			}
			println("Error saving image: \(url)")
		}
		return false
	}

	func save(text1: String, text2: String, originalImage: UIImage, memeImage: UIImage, id: String?) -> Bool {
		if let url = resourceURL {
			return (
				saveImage(originalImage, ofType: .Source, withBaseUrl: url) &&
				saveImage(memeImage, ofType: .Meme, withBaseUrl: url) &&
				saveImage(memeImage, ofType: .MemeThumbnail, withBaseUrl: url, asThumbnail: true) &&
				saveTexts(bottomText: text1, topText: text2)
			)
		}
		return false
	}

	func saveTexts(#bottomText: String, topText: String) -> Bool {
		// TODO: serialize texts to file
		return false
	}





	func delete() {
		// TODO: delete stored images and texts
	}
}