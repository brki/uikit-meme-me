//
//  DetailViewController.swift
//  imagepicker
//
//  Created by Brian on 03/08/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

	@IBOutlet weak var imageView: UIImageView!

	var meme: Meme?

	override func viewWillAppear(animated: Bool) {
		if let meme = meme {
			imageView.image = meme.image(.Meme)
		}
	}
}
