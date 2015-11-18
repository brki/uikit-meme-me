//
//  DetailViewController.swift
//  PocketMeme
//
//  Created by Brian on 03/08/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController {

	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var editButton: UIBarButtonItem!
	@IBOutlet weak var trashButton: UIBarButtonItem!

	var meme: Meme?
	var mainObjectContext: NSManagedObjectContext!

	override func viewDidLoad() {
		navigationItem.rightBarButtonItems = [trashButton, editButton]
	}

	override func viewWillAppear(animated: Bool) {
		if let meme = meme {
			imageView.image = meme.image(.Meme)
		}
	}

	/**
	Deletes the meme and returns to the previous view controller.
	*/
	@IBAction func deleteMeme(sender: UIBarButtonItem) {
		if let meme = meme {
			let alertController = UIAlertController(title: "Delete Meme", message: "It will be gone for good. Are you sure?", preferredStyle: .Alert)
			alertController.addAction(
				UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action: UIAlertAction) in
					MemeList.sharedInstance.removeMeme(meme)
					self.navigationController?.popViewControllerAnimated(true)
				})
			)
			alertController.addAction(
				UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
			)
			presentViewController(alertController, animated: true, completion: nil)
		}
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let id = segue.identifier where id == "toEditorFromDetail" {
			let editorVC = segue.destinationViewController as! EditorViewController
			editorVC.mainObjectContext = mainObjectContext
			editorVC.isPresentingExistingMeme = true
			editorVC.memeTransitionImage = meme?.image(.Source)
			editorVC.meme = meme
		}
	}

}
