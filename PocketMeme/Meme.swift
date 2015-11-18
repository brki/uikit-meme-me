//
//  Meme.swift
//  PocketMeme
//
//  Created by Brian on 18/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit
import CoreData

class  Meme: NSManagedObject {

    enum ImageType {
        case Source, Meme, MemeThumbnailSmall, MemeThumbnailLarge
    }

	enum StorageArea {
		case Temporary, Permanent
	}

	@NSManaged var id: String!
	@NSManaged var topText: String
	@NSManaged var bottomText: String
    @NSManaged var originalImage: NSData
    @NSManaged var memeImage: NSData
    @NSManaged var thumbnailSmall: NSData
    @NSManaged var thumbnailLarge: NSData
    @NSManaged var creationDate: NSDate

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(id: String? = nil, topText: String = "", bottomText: String = "", creationDate: NSDate? = nil, managedObjectContext: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Meme", inManagedObjectContext: managedObjectContext)!
        super.init(entity: entity, insertIntoManagedObjectContext: managedObjectContext)
        
		self.id = id ?? NSUUID().UUIDString
        self.creationDate = creationDate ?? NSDate()
		self.topText = topText
		self.bottomText = bottomText
	}

	/**
	Fetches the image.
	*/
	func image(type: ImageType) -> UIImage?
	{
        var data: NSData
        switch type {
        case .Source:
            data = originalImage
        case .Meme:
            data = memeImage
        case .MemeThumbnailSmall:
            data = thumbnailSmall
        case .MemeThumbnailLarge:
            data = thumbnailLarge
        }
		return UIImage(data: data)
	}

	/**
	Sets the underlying NSData image attribute with the JPEG data representation of the provided UIImage.

	JPEG is used instead of PNG because UIImageJPEGRepresentation preserves the image orientation information,
	whereas UIImagePNGRepresentation does not.
	*/
    func setImage(image: UIImage, forType type: ImageType) {
        guard let data = UIImageJPEGRepresentation(image, 0.9) else {
            print("Unable to get NSData representation of passed image")
            return
        }
        switch type {
        case .Source:
            originalImage = data
        case .Meme:
            memeImage = data
			generateThumbnails(image)
        case .MemeThumbnailSmall:
            thumbnailSmall = data
        case .MemeThumbnailLarge:
            thumbnailLarge = data
        }
    }

	/**
	Gets the appropriately sized image based on the image and the type.

	If the type is a thumbnail type, a thumbnail image is generated and returned.
	Otherwise, the original image is returned.
	*/
	func sizedImage(image: UIImage, ofType type: ImageType) -> UIImage? {
		if type == ImageType.MemeThumbnailSmall || type == ImageType.MemeThumbnailLarge {
			return thumbNailImage(image, ofType: type)
		} else {
			return image
		}
	}

    func generateThumbnails(image: UIImage) {
        if let thumbnail = thumbNailImage(image, ofType: .MemeThumbnailSmall) {
            self.setImage(thumbnail, forType: .MemeThumbnailSmall)
        } else {
            print("Unable to generate small thumbnail image")
        }
        if let thumbnail = thumbNailImage(image, ofType: .MemeThumbnailLarge) {
            self.setImage(thumbnail, forType: .MemeThumbnailLarge)
        } else {
            print("Unable to generate large thumbnail image")
        }
    }
    
	func thumbNailImage(image: UIImage, ofType type: ImageType) -> UIImage? {
		if let size = sizeForThumbnailType(type) {
			return image.scaledToFitSize(size, withScreenScale: UIScreen.mainScreen().scale)
		} else {
			print("Unexpected type received: \(type)")
			return nil
		}
	}

	func sizeForThumbnailType(type: ImageType) -> CGSize? {
		switch type {
		case ImageType.MemeThumbnailSmall:
			return Constants.MemeImageSizes.smallThumbnail
		case ImageType.MemeThumbnailLarge:
			return Constants.MemeImageSizes.largeThumbnail
		default:
			return nil
		}
	}
}
