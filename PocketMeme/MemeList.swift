//
//  MemeList.swift
//  PocketMeme
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

// This is a slow and dirty way to persist the list of memes.
// For a production-ready app, a better storage mechanism would be used.

/**
Used to manage saving and deleting memes from permanent storage.
*/
class MemeList {
	var list = [Meme]()
	static let dataFile = "memeList.data"
	static let sharedInstance = MemeList()

	/**
	The url of the persistent data file.
    */
	var dataURL: NSURL {
		return documentDirectoryURL().URLByAppendingPathComponent(MemeList.dataFile)
	}

	// Convenience subscript access to underlying list.
	subscript(index: Int) -> Meme {
		return list[index]
	}

	/**
	Load the persisted Memes into memory from storage.
    */
	init() {
		guard let dataStorePath = dataURL.path where NSFileManager.defaultManager().fileExistsAtPath(dataStorePath) else {
			print("No persisted data to load")
			return
		}
		guard let unarchivedList = NSKeyedUnarchiver.unarchiveObjectWithFile(dataStorePath) as? [Meme] else {
			print("Unable to unarchive data in expected form")
			return
		}
		list = unarchivedList
	}

	/**
	Persists the in-memory list of Memes to storage.
	*/
	func persist() {
		guard let dataStorePath = dataURL.path else {
			print("Unable to get data store path")
			return
		}
		NSKeyedArchiver.archiveRootObject(list, toFile: dataStorePath)
	}

	/**
	Saves the provided meme to persistent storage.
	*/
	func saveMeme(meme: Meme) {
		if let index = indexOfMeme(meme) {
			list[index] = meme
		} else {
			list.insert(meme, atIndex: 0)
		}
		persist()
	}

	/**
	Remove the given meme from persistent storage.
    */
	func removeMeme(meme: Meme) {
		if let index = indexOfMeme(meme) {
			removeMemeAtIndex(index)
		}
	}

	/**
	Remove the meme at the given index from persistent storage.

	This also calls ``meme.removePersistedData()``
	*/
	func removeMemeAtIndex(index: Int) {
		let meme = list[index]
		meme.removePersistedData()
		list.removeAtIndex(index)
		persist()
	}

	/**
	Find the index in self.list of the given meme.
	
	- returns: Int index, or nil if not found
	*/
	func indexOfMeme(meme: Meme) -> Int? {
		for (index, storedMeme) in list.enumerate() {
			if storedMeme.id == meme.id {
				return index
			}
		}
		return nil
	}

}
