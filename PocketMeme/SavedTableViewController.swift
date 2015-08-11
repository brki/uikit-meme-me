//
//  SavedTableViewController.swift
//  PocketMeme
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class SavedTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

	@IBOutlet weak var tableView: UITableView!

	weak var memeList: MemeList!

	enum TableCellTag: Int {
		case imageView = 1
		case topText = 2
		case bottomText = 3
	}

	let tableCellHeight = CGFloat(Constants.MemeImageSizes.smallThumbnail.height + 6)

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self
		memeList = MemeList.sharedInstance
	}

	override func viewWillAppear(animated: Bool) {
		self.tabBarController!.tabBar.hidden = false
		tableView.reloadData()
		super.viewWillAppear(animated)
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Hide the tab bar on the current controller's view before pushing, so that there's not an ugly animation
		// of hiding the tab bar after the destination VC has appeared.
		// The destination view controller has a storyboard property that hides the tabbar for it's view.
		self.tabBarController!.tabBar.hidden = true
		if let identifier = segue.identifier {
			if identifier == "detailFromTableView" {
				let detailVC = segue.destinationViewController as! DetailViewController
				if let path = tableView.indexPathForSelectedRow() {
					detailVC.meme = memeList[path.row]
				}
			}
		}
	}


	// MARK: UITableViewDelegate methods:

	func deleteMeme(action: UITableViewRowAction!, indexPath: NSIndexPath!) {
		memeList.removeMemeAtIndex(indexPath.row)
	}

	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return tableCellHeight
	}

	func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return tableCellHeight
	}


	// MARK: UITableViewDataSource methods:

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return memeList.list.count
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("savedMeme") as! UITableViewCell
		let meme = memeList[indexPath.row]
		let image = meme.image(Meme.ResourceType.MemeThumbnailSmall)
		if let imageView = cell.contentView.viewWithTag(TableCellTag.imageView.rawValue) as? UIImageView {
			imageView.image = meme.image(Meme.ResourceType.MemeThumbnailSmall)
		}
		if let topText = cell.contentView.viewWithTag(TableCellTag.topText.rawValue) as? UILabel {
			topText.text = meme.topText
		}
		if let bottomText = cell.contentView.viewWithTag(TableCellTag.bottomText.rawValue) as? UILabel {
			bottomText.text = meme.bottomText
		}
		return cell
	}

	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			memeList.removeMemeAtIndex(indexPath.row)
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
		}
	}
}
