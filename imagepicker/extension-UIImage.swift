//
//  extension-UIImage.swift
//  imagepicker
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
	func crop(aRect: CGRect) -> UIImage? {
		let rect = CGRectMake(
			aRect.origin.x * self.scale,
			aRect.origin.y * self.scale,
			aRect.size.width * self.scale,
			aRect.size.height * self.scale)

		let cgImage = CGImageCreateWithImageInRect(self.CGImage, rect)
		let croppedImage = UIImage(CGImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
		return croppedImage
	}
}
