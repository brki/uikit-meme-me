//
//  MemeNavigationController.swift
//  imagepicker
//
//  Created by Brian on 09/08/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit


class MemeNavigationController: UINavigationController {

	/**
	Overridden so that the EditorViewController can take a snapshot of the screen before
	being popped of the navigation stack.
	
	An alternative would have been to use the ``viewWillDisappear()`` method of
	EditorViewController, but at that point apparently it's too late to make changes
	to the views before calling ``drawViewHierarchyInRect(_, afterScreenUpdates: true)`
	to get the snapshot. Done from ``viewWilDisappear()``, the snapshot is taken, but it
	seems the screen updates are not done.
	
	Calling the same code from ``popViewControllerAnimated``, in constrast, allows hiding
    the cursor of the text field before the snapshot is taken.
	*/
	override func popViewControllerAnimated(animated: Bool) -> UIViewController? {
		if let editorVC = viewControllers.last as? EditorViewController {
			editorVC.viewControllerIsBeingPopped()
		}
		return super.popViewControllerAnimated(animated)
	}

}
