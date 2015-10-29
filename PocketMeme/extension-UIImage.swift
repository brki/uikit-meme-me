//
//  extension-UIImage.swift
//  PocketMeme
//
//  Created by Brian on 29/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

public extension UIImage {

	/**
	Crop the image, preserving it's orientation.
	
	Based on http://stackoverflow.com/a/8443937/948341
	*/
	func crop(aRect: CGRect, screenScale: CGFloat) -> UIImage? {
		let rect = scaledRect(aRect, scale: screenScale)
		guard let cgImage = CGImageCreateWithImageInRect(self.CGImage, rect) else {
			return nil
		}
		let croppedImage = UIImage(CGImage: cgImage, scale: screenScale, orientation: self.imageOrientation)
		return croppedImage
	}

	/**
	Returns a scaled-down image if scaling down is necessary for image to fit in the provided size.
	*/
	func scaledToFitSize(size: CGSize, withScreenScale screenScale: CGFloat) -> UIImage? {
		let scale = scaleToFitInRectOfSize(size)
		if scale < 1 {
			let rect = scaledRect(CGRect(origin: CGPointZero, size: self.size), scale: scale)
			UIGraphicsBeginImageContextWithOptions(rect.size, true, screenScale)
			self.drawInRect(rect)
			let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return scaledImage
		}
		return self
	}

	func scaleToFitInRectOfSize(size: CGSize) -> CGFloat {
		let verticalRatio = size.height / self.size.height
		let horizontalRatio = size.width / self.size.width
		return min(1, min(horizontalRatio, verticalRatio))
	}

	func scaledRect(rect: CGRect, scale: CGFloat) -> CGRect {
		return CGRectMake(
			rect.origin.x * scale,
			rect.origin.y * scale,
			rect.size.width * scale,
			rect.size.height * scale)
	}
}
