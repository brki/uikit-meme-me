//
//  Meme.swift
//  PocketMeme
//
//  Created by Brian on 18/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class  Meme: NSObject, NSCoding {


	enum ResourceType: String {
		case Source = "source"
		case Meme = "meme"
		case MemeThumbnailSmall = "meme-thumbnail-small"
		case MemeThumbnailLarge = "meme-thumbnail-large"
		case Texts = "texts"
	}

	enum StorageArea {
		case Temporary, Permanent
	}

	// A cache shared by all Meme instances:
	static let cache = NSCache()

	var id: String!
	var topText: String
	var bottomText: String

	/**
	Provides the URL of the directory to use for storing images for the current meme.
	*/
	func resourceURL(forStorageArea storageArea: StorageArea) -> NSURL? {
		
		let directoryURL = storageArea == .Temporary ? tmpDirectoryURL() : documentDirectoryURL()
		let resourceURL = directoryURL.URLByAppendingPathComponent(id, isDirectory: true)
		var error: NSError?
		// Try to create the directory, if it doesn't already exist:
		NSFileManager.defaultManager().createDirectoryAtURL(resourceURL, withIntermediateDirectories: true, attributes: nil, error: &error)
		if let err = error {
			println("Unable to create directory for resource contents. Error: \(err.localizedDescription)")
		} else {
			return resourceURL
		}
		return nil

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

	/**
	NSCoding init()
	*/
	required convenience init(coder decoder: NSCoder) {
		self.init(
			id: decoder.decodeObjectForKey("id") as! String?,
			topText: decoder.decodeObjectForKey("topText") as! String,
			bottomText: decoder.decodeObjectForKey("bottomText") as! String
		)
	}

	deinit {
		// Clear any items from the cache.
		for type in [ResourceType.Source, ResourceType.Meme, ResourceType.MemeThumbnailSmall, ResourceType.MemeThumbnailLarge] {
			Meme.cache.removeObjectForKey(imageNameForType(type))
		}
	}

	/**
	NSCoding encodeWithCoder()
	*/
	func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(id, forKey: "id")
		coder.encodeObject(topText, forKey: "topText")
		coder.encodeObject(bottomText, forKey: "bottomText")
	}

	/**
	Fetches the image
	*/
	func image(type: ResourceType, fromStorageArea storageArea: StorageArea = .Permanent) -> UIImage?
	{
		let name = imageNameForType(type)
		if let image = Meme.cache.objectForKey(name) as? UIImage {
			return image
		}
		if let baseUrl = resourceURL(forStorageArea: storageArea), let imageFile = baseUrl.URLByAppendingPathComponent(name).path {
			if let image = UIImage(contentsOfFile: imageFile) {
				Meme.cache.setObject(image, forKey: name)
				return image
			}
		}
		return nil
	}

	/**
	*/
	func imageNameForType(type: ResourceType) -> String {
		let scale = UIScreen.mainScreen().scale
		return "\(id)-\(type.rawValue)@\(scale)x.png"
	}

	/**
	Persists the original image, the meme image, and meme thumbnail image.
	
	The persisted images are stored together in a directory specific to this meme.
	For example, if the meme.id == "foo", then this will result in these files being created or updated:
		~Documents/foo/
						foo-source.png
						foo-meme.png
						foo-meme-thumbnail.png
	*/
	func persistOriginalImage(image: UIImage, toStorageArea storageArea: StorageArea = .Temporary) -> Bool {
		if let url = resourceURL(forStorageArea: storageArea) {
			return saveImage(image, ofType: .Source, withBaseUrl: url, toStorageArea: storageArea)
		}
		return false
	}

	func persistMemeImage(memeImage: UIImage, toStorageArea storageArea: StorageArea = .Temporary) -> Bool {
		if let url = resourceURL(forStorageArea: storageArea) {
			return (
				saveImage(memeImage, ofType: .Meme, withBaseUrl: url, toStorageArea: storageArea)
					&& saveImage(memeImage, ofType: .MemeThumbnailSmall, withBaseUrl: url, toStorageArea: storageArea)
					&& saveImage(memeImage, ofType: .MemeThumbnailLarge, withBaseUrl: url, toStorageArea: storageArea)
			)
		}
		return false
	}

	func saveImage(an_image: UIImage, ofType type: ResourceType, withBaseUrl baseUrl: NSURL, toStorageArea storageArea: StorageArea) -> Bool {
		let name = imageNameForType(type)
		if let image = sizedImage(an_image, ofType: type) {
			let data = UIImagePNGRepresentation(image)
			let url = baseUrl.URLByAppendingPathComponent(name, isDirectory: false)
			if data.writeToURL(url, atomically: true) {
				Meme.cache.setObject(image, forKey: name)
				return true
			}
		}
		println("Error saving image")
		return false
	}

	/**
	Gets the appropriately sized image based on the image and the type.
	
	If the type is a thumbnail type, a thumbnail image is generated and returned.
	Otherwise, the original image is returned.
	*/
	func sizedImage(image: UIImage, ofType type: ResourceType) -> UIImage? {
		if type == ResourceType.MemeThumbnailSmall || type == ResourceType.MemeThumbnailLarge {
			return thumbNailImage(image, ofType: type)
		} else {
			return image
		}
	}

	func thumbNailImage(image: UIImage, ofType type: ResourceType) -> UIImage? {
		var targetSize: CGSize?
		if let size = sizeForThumbnailType(type) {
			return image.scaledToFitSize(size, withScreenScale: UIScreen.mainScreen().scale)
		} else {
			println("Unexpected type received: \(type)")
			return nil
		}
	}

	func sizeForThumbnailType(type: ResourceType) -> CGSize? {
		switch type {
		case ResourceType.MemeThumbnailSmall:
			return Constants.MemeImageSizes.smallThumbnail
		case ResourceType.MemeThumbnailLarge:
			return Constants.MemeImageSizes.largeThumbnail
		default:
			return nil
		}
	}

	/**
	Removes the entire directory that contained images for the Meme.
	*/
	func removePersistedData(forStorageArea storageArea: StorageArea = .Permanent) -> Bool {
		if let url = resourceURL(forStorageArea: storageArea) {
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

	func moveToPermanentStorage() -> Bool {
		// TODO: handle case where destination already exists
		// TODO: handle non existance of temp dir
		if let tempURL = resourceURL(forStorageArea: .Temporary), permanentURL = resourceURL(forStorageArea: .Permanent) {
			let fileManager = NSFileManager.defaultManager()
			// Remove any previous items there:
			fileManager.removeItemAtURL(permanentURL, error: nil)
			var error: NSError?
			NSFileManager.defaultManager().moveItemAtURL(tempURL, toURL: permanentURL, error: &error)
			if let err = error {
				println("Error in moveToPermanentStorage: \(err)")
				return false
			}
		}
		return true
	}

	func cleanTempStorage() {
		if let tempURL = resourceURL(forStorageArea: .Temporary) {
			NSFileManager.defaultManager().removeItemAtURL(tempURL, error: nil)
		}
	}
}
