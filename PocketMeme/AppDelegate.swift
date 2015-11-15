//
//  AppDelegate.swift
//  PocketMeme
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//



/**
This app was only designed for / tested on iPhone, not iPad.

* The app saves the memes to permanent storage using CoreData.

* From the meme editor, if you press the back button, the meme is saved.
  In order to be able to get the meme image at this point in time, a custom
  NavigationController subclass is used.

* The generated meme images are cropped to remove any border around the image
  in the UIImageView

* Some optimization was made so that the application is more responsive.
  More specifically: saving the original image is a slow operation on
  a real device (tested with iPhone 4s).  So, this is done in a background
  thread to a temporary directory when the image is selected.  All meme images
  are also saved initially to the temp directory.  The temp directory contents
  are moved to the permanentstorage location when leaving the editor (which is quick).

* Large and small thumbnail images are saved to permanent storage so that
  there is no need to load / scale down the full-sized Meme images in order
  to display the table and collection views.

*/




import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
}

