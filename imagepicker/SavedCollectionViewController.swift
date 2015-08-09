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

	@IBOutlet weak var collectionView: UICollectionView!

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self
		collectionView.delegate = self
		memeList = MemeList.sharedInstance
	}

	override func viewWillAppear(animated: Bool) {
		collectionView.reloadData()
		super.viewWillAppear(animated)
	}

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return memeList.list.count
	}

	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("savedCollectionCell", forIndexPath: indexPath) as! MemeCollectionViewCell
		let meme = memeList[indexPath.item]
		cell.imageView.image = meme.image(.MemeThumbnailLarge)
		return cell
	}
}
