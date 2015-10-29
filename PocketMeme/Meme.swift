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

	// A cache shared by all Meme instances.
	// The in-memory size of the images is used as a cache cost;
	// the cache total limit is 200 MB (but can vary according to cache
	// implementation details).
	static let cache = {() -> NSCache in
		let aCache = NSCache()
		aCache.totalCostLimit = 200 * 1024 * 1024
		return aCache
		}()

	var id: String!
	var topText: String
	var bottomText: String

	init(var id: String? = nil, topText: String = "", bottomText: String = "") {
		if id == nil {
			id = NSUUID().UUIDString
		}
		self.id = id
		self.topText = topText
		self.bottomText = bottomText

		// Have the
		Meme.cache.totalCostLimit = 200 * 1024 * 1024
		super.init()
	}

	/**
	NSCoding init()
	*/
	required convenience init?(coder decoder: NSCoder) {
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
	Fetches the image.
	
	Looks for the image first in the cache, and then in the provided storageArea.
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
				Meme.cache.setObject(image, forKey: name, cost: cacheCostForImage(image))
				return image
			}
		}
		return nil
	}

	/**
	Provides the file name for the given image type for this meme.
	*/
	func imageNameForType(type: ResourceType) -> String {
		return "\(id)-\(type.rawValue).png"
	}

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

	/**
	Persists the image to a meme-specific directory in the designated storageArea.
	*/
	func saveImage(an_image: UIImage, ofType type: ResourceType, withBaseUrl baseUrl: NSURL, toStorageArea storageArea: StorageArea) -> Bool {
		let name = imageNameForType(type)
		if let image = sizedImage(an_image, ofType: type),
			data = UIImagePNGRepresentation(image) {
				let url = baseUrl.URLByAppendingPathComponent(name, isDirectory: false)
				if data.writeToURL(url, atomically: true) {
					Meme.cache.setObject(image, forKey: name)
					return true
				}
		}
		print("Error saving image")
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
		if let size = sizeForThumbnailType(type) {
			return image.scaledToFitSize(size, withScreenScale: UIScreen.mainScreen().scale)
		} else {
			print("Unexpected type received: \(type)")
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
	Provides the URL of the directory to use for storing images for the current meme.
	*/
	func resourceURL(forStorageArea storageArea: StorageArea) -> NSURL? {

		let directoryURL = storageArea == .Temporary ? tmpDirectoryURL() : documentDirectoryURL()
		let resourceURL = directoryURL.URLByAppendingPathComponent(id, isDirectory: true)
		var error: NSError?
		do {
			// Try to create the directory, if it doesn't already exist:
			try NSFileManager.defaultManager().createDirectoryAtURL(resourceURL, withIntermediateDirectories: true, attributes: nil)
		} catch let error1 as NSError {
			error = error1
		}
		if let err = error {
			print("Unable to create directory for resource contents. Error: \(err.localizedDescription)")
		} else {
			return resourceURL
		}
		return nil

	}
	
	/**
	Removes the entire directory that contained images for the Meme.
	*/
	func removePersistedData(forStorageArea storageArea: StorageArea = .Permanent) -> Bool {
		if let url = resourceURL(forStorageArea: storageArea) {
			var error: NSError?
			do {
				try NSFileManager.defaultManager().removeItemAtURL(url)
			} catch let error1 as NSError {
				error = error1
			}
			if let err = error {
				print("Error trying to remove resources for id '\(id)': \(err)")
			} else {
				return true
			}
		}
		return false
	}

	/**
	Move any items from the temp dir to the permanent dir.
	*/
	func moveToPermanentStorage() -> Bool {
		if let tempURL = resourceURL(forStorageArea: .Temporary), permanentURL = resourceURL(forStorageArea: .Permanent), tempPath = tempURL.path {
			let fileManager = NSFileManager.defaultManager()
			var error: NSError?
			let files: [AnyObject]?
			do {
				files = try fileManager.contentsOfDirectoryAtPath(tempPath)
			} catch let error1 as NSError {
				error = error1
				files = nil
			}
			if error != nil{
				print("Unable to get list of files in meme's temp dir")
				return false
			}
			for filename: String in files as! [String] {
				let destURL = permanentURL.URLByAppendingPathComponent(filename)
				do {
					// Ignore an error trying to remove the item; this most likely means it didn't exist in the first place:
					try fileManager.removeItemAtURL(destURL)
				} catch _ {
				}
				let sourceURL = tempURL.URLByAppendingPathComponent(filename)
				do {
					try fileManager.moveItemAtURL(sourceURL, toURL: destURL)
				} catch let error1 as NSError {
					error = error1
				}
				if error != nil {
					print("Unable to move item from \(sourceURL) to \(destURL)")
					return false
				}
			}
			return true
		} else {
			print("Error getting URLs for Temporary and Permanent storage locations")
			return false
		}
	}

	/**
	Returns the in-memory size of the UIImage.
	*/
	func cacheCostForImage(uiImage: UIImage) -> Int {
		let image = uiImage.CGImage
		return CGImageGetBytesPerRow(image) * CGImageGetHeight(image)
	}

	/**
	Purges the temporary directory for this meme.
	*/
	func cleanTempStorage() {
		if let tempURL = resourceURL(forStorageArea: .Temporary) {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(tempURL)
			} catch _ {
			}
		}
	}
}
