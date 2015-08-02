//
//  SentViewController.swift
//  imagepicker
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class SavedTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

	@IBOutlet weak var tableView: UITableView!

	var memeList: MemeList!

	override func viewDidLoad() {
		tableView.delegate = self
		tableView.dataSource = self
		memeList = MemeList.sharedInstance
	}

	override func viewWillAppear(animated: Bool) {
		tableView.reloadData()
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let identifier = segue.identifier {
			if identifier == "fromListToEditor" {
				// Hide the tab bar on the current controller's view before pushing, so that there's not an ugly animation
				// of hiding the tab bar after the destination VC has appeared.
				// The destination view controller has a storyboard property that hides the tabbar for it's view.
				self.tabBarController!.tabBar.hidden = true
			}
		}
	}


	// MARK: UITableViewDelegate methods:

	func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
		// TODO: show detail view
	}

	func deleteMeme(action: UITableViewRowAction!, indexPath: NSIndexPath!) {
		memeList.removeMemeAtIndex(indexPath.row)
	}


	// MARK: UITableViewDataSource methods:

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return memeList.list.count
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("savedMeme") as! UITableViewCell
		let meme = memeList[indexPath.row]
		let image = meme.image(Meme.ResourceType.MemeThumbnail)
		cell.imageView!.image = meme.image(Meme.ResourceType.MemeThumbnail)
		cell.textLabel!.text = meme.topText + " / " + meme.bottomText
		return cell
	}

	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			memeList.removeMemeAtIndex(indexPath.row)
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
			tableView.reloadData()
		}
	}
}
