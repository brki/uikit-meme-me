//
//  SavedCollectionViewController.swift
//  imagepicker
//
//  Created by Brian on 02/08/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class SavedCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

	weak var memeList: MemeList!
	var selectedIndexPath: NSIndexPath?

	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var flowLayout: UICollectionViewFlowLayout!

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self
		collectionView.delegate = self
		memeList = MemeList.sharedInstance
		setFlowLayoutValues()
	}

	override func viewWillAppear(animated: Bool) {
		collectionView.reloadData()
		self.tabBarController!.tabBar.hidden = false
		super.viewWillAppear(animated)
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Hide the tab bar on the current controller's view before pushing, so that there's not an ugly animation
		// of hiding the tab bar after the destination VC has appeared.
		// The destination view controller has a storyboard property that hides the tabbar for it's view.
		self.tabBarController!.tabBar.hidden = true
		if let identifier = segue.identifier {
			if identifier == "detailFromCollectionView" {
				let detailVC = segue.destinationViewController as! DetailViewController
				if let indexPath = selectedIndexPath {
					detailVC.meme = memeList[indexPath.item]
				}
				selectedIndexPath = nil
			}
		}
	}

	/**
	Sets the minimum inter-image spacing in row and the insets for the flow layout.
	*/
	func setFlowLayoutValues() {
		let availableWidth = UIScreen.mainScreen().applicationFrame.width
		let thumbnailWidth = Constants.MemeImageSizes.largeThumbnail.width
		let extraSpace =  availableWidth % thumbnailWidth
		// There is one more spacing-area than images in the row:
		let spacingAreasPerRow = CGFloat(Int(availableWidth / thumbnailWidth) + 1)
		let spacing = CGFloat(max(Int(extraSpace / spacingAreasPerRow), 1))
		let edgeInsets = UIEdgeInsets(top: 2, left: spacing, bottom: 2, right: spacing)

		flowLayout.minimumInteritemSpacing = spacing
		flowLayout.sectionInset = edgeInsets
	}


	// MARK: UICollectionView data source methods

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return memeList.list.count
	}

	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("savedCollectionCell", forIndexPath: indexPath) as! MemeCollectionViewCell
		let meme = memeList[indexPath.item]
		cell.imageView.image = meme.image(.MemeThumbnailLarge)
		return cell
	}


	// MARK: UICollectionView delegate methods

	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		selectedIndexPath = indexPath
		performSegueWithIdentifier("detailFromCollectionView", sender: self)
	}
}
