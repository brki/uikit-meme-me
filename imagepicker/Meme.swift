//
//  Meme.swift
//  imagepicker
//
//  Created by Brian on 18/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class  Meme: NSObject, NSCoding {
	var id: String?
	var topText: String
	var bottomText: String

	enum ResourceType: String {
		case Source = "source"
		case Meme = "meme"
		case MemeThumbnail = "meme-thumbnail"
		case Texts = "texts"
	}

	init(var id: String? = nil, topText: String = "", bottomText: String = "") {
		if id == nil {
			id = NSUUID().UUIDString
		}
		self.id = id
		self.topText = topText
		self.bottomText = bottomText
		super.init()
	}

	required convenience init(coder decoder: NSCoder) {
		self.init(
			id: decoder.decodeObjectForKey("id") as! String?,
			topText: decoder.decodeObjectForKey("topText") as! String,
			bottomText: decoder.decodeObjectForKey("bottomText") as! String
		)
	}

	func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(id, forKey: "id")
		coder.encodeObject(topText, forKey: "topText")
		coder.encodeObject(bottomText, forKey: "bottomText")
	}

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

	func persistImages(originalImage: UIImage, memeImage: UIImage) -> Bool {
		if let url = resourceURL {
			return (
				saveImage(originalImage, ofType: .Source, withBaseUrl: url) &&
				saveImage(memeImage, ofType: .Meme, withBaseUrl: url) &&
				saveImage(memeImage, ofType: .MemeThumbnail, withBaseUrl: url, asThumbnail: true)
			)
		}
		return false
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

	var resourceURL: NSURL? {
		if let id = id {

			let documentURL = documentDirectoryURL()
			let resourceURL = documentURL.URLByAppendingPathComponent(id, isDirectory: true)
			var error: NSError?
			// Try to create the directory, if it doesn't already exist:
			NSFileManager.defaultManager().createDirectoryAtURL(resourceURL, withIntermediateDirectories: true, attributes: nil, error: &error)
			if let err = error {
				println("Unable to create directory for resource contents. Error: \(err.localizedDescription)")
			} else {
				return resourceURL
			}
		} else {
			println("Can not provide URL for Meme that has no id")
		}
		return nil
	}

	func removePersistedData() -> Bool {
		if let url = resourceURL {
			var error: NSError?
			NSFileManager.defaultManager().removeItemAtURL(url, error: &error)
			if let err = error {
				println("Error trying to remove resources for id '\(id)': \(err)")
			} else {
				return true
			}
		}
		return false
	}
}