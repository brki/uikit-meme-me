//
//  MemeList.swift
//  PocketMeme
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import CoreData

/**
Used to manage saving and deleting memes from permanent storage.
*/
class MemeList {
	static let sharedInstance = MemeList()
    
    var list = [Meme]()
	let sharedContext = CoreDataStack.sharedInstance.mainManagedObjectContext

	// Convenience subscript access to underlying list.
	subscript(index: Int) -> Meme {
		return list[index]
	}

	/**
	Load the persisted Memes into memory from storage.
    */
	init() {
		loadMemes()
	}

	func loadMemes() {
		let request = NSFetchRequest(entityName: "Meme")
		request.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		sharedContext.performBlockAndWait {
			do {
				self.list = try self.sharedContext.executeFetchRequest(request) as! [Meme]
			} catch let error as NSError {
				print("Error fetching Memes: \(error)")
			}
		}
	}

	/**
	Remove the given meme from persistent storage.
    */
	func removeMeme(meme: Meme) {
		guard let index = indexOfMeme(meme) else {
			print("removeMeme called, but meme not found in list")
			return
		}
		removeMemeAtIndex(index)
	}
    
    /**
     Remove the meme at the given index from persistent storage.
     */
    func removeMemeAtIndex(index: Int) {
        let meme = list.removeAtIndex(index)

		sharedContext.performBlockAndWait {
			self.sharedContext.deleteObject(meme)
			do {
				// Push changes to parent context
				try self.sharedContext.save()
				guard let backgroundContext = self.sharedContext.parentContext else {
					print("Unable to get parent context")
					return
				}
				backgroundContext.performBlock {
					do {
						try backgroundContext.save()
					} catch let error as NSError {
						// TODO: better handling
						print("Error saving to persistent store: \(error)")
					}
				}
			} catch let error as NSError {
				// TODO: better handling
				print("Error saving in main context after deleting: \(error)")
			}
		}
    }

	/**
	Find the index in self.list of the given meme.

	returns: Int index, or nil if not found
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
