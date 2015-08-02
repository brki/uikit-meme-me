//
//  SentViewController.swift
//  imagepicker
//
//  Created by Brian on 26/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

class SentTableViewController: UIViewController {

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

}
