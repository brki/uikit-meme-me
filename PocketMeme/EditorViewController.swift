//
//  EditorViewController.swift
//  PocketMeme
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//


/**
Some optimization was made so that the application is more responsive.
More specifically: saving the original image is a slow operation on 
a real device (tested with iPhone 4s).  So, this is done in a background
thread to a temporary directory.  All meme images are also saved initially
to the temp directory.  The temp directory is moved to the permanent storage
location when leaving the editor (which is quick).
*/


/** TODO: performance optimization, because saving the original image is slow.
When image picked: save meme, including original image, in a background thread to a meme-name-temp directory.
On cancel, discard temp directory.
On non-cancel:
  * persist meme-image and meme-texts to tmp dir
  * move tmp dir to final dir name
  * pop to (root?) vc.

Also, look into NSURL bookmarks.

Also, clean up tmp dir on app exit.
*/


// TODO: FIXME: on device (and simulator), with a photo as image (in portrait), when editing bottom text, and switch to icon kb, then back to normal kb,
//              the text is no longer visible. (and image doesn't slide down after dismissing kb).
//              Also happens with device in landscape mode

// TODO FIXME: bit weird to specify from controller where images should go (.Temporary, .Permanent).  What's a better way.

// STILL TODO:
// look into NSURL bookmarks.
// clean up tmp dir on app exit.

import UIKit

class EditorViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoButton: UIBarButtonItem!
    @IBOutlet weak var topText: UITextField!
	@IBOutlet weak var bottomText: UITextField!
    @IBOutlet weak var memeCanvas: UIView!
	@IBOutlet weak var shareButton: UIBarButtonItem!
	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet var canvasBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var canvasTopConstraint: NSLayoutConstraint!
	@IBOutlet weak var bottomToolbar: UIToolbar!

	var meme: Meme?
	var shareMemeImage: UIImage?
    var activeTextField: UITextField?
	var textFieldConstraints = [NSLayoutConstraint]()
	var isPresentingExistingMeme = false
	var memeTransitionImage: UIImage?  // Image can be specified by pushing controller; will be shown in editor during push animation.
	var saveOnExit = true
	var isRotating = false

	var currentCanvasVerticalOffset: CGFloat = 0

	// Whether or not the meme has been changed since creation or last save:
	var dirtyMeme = false {
		didSet(oldValue) {
			if oldValue != dirtyMeme {
				cancelButton.enabled = dirtyMeme
			}
		}
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        photoButton.enabled = UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)
        topText.delegate = self
		bottomText.delegate = self
        setDefaultTextAttributes()

        let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self, selector: "keyboardSizeChanging:", name: UIKeyboardWillChangeFrameNotification, object: nil)
    }

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	/**
	Ensure that the appropriate elements are shown or hidden, and that the text fields are appropriately sized,
	depending on whether or not an image is present, and whether or not the meme already exists.
	*/
    override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		if isPresentingExistingMeme {
			if let meme = meme {
				if let image = memeTransitionImage {
					imageView.image = image
				}
				topText.text = meme.topText
				bottomText.text = meme.bottomText
			}
		} else {
			if meme == nil {
				meme = Meme(id: nil, topText: topText.text, bottomText: bottomText.text)
			}
		}
		cancelButton.enabled = dirtyMeme
		shareButton.enabled = imageView.image != nil
		navigationItem.rightBarButtonItems = [cancelButton, shareButton]
		setTextFieldsHidden(true)
    }

	/**
	When the text in a textbox shrinks, the views are layed out again, and it may be necessary to
	reposition the memeCanvas view to ensure that the text field remains visible.
	*/
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		println("viewDidLayoutSubviews")
		if let tf = activeTextField {
			println("textfieldframe: \(tf.frame)")
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		if isPresentingExistingMeme {
			isPresentingExistingMeme = false
			if let meme = meme {
				if let image = meme.image(.Source, fromStorageArea: .Permanent) {
					imageView.image = image
					memeTransitionImage = nil
				}
			}
		}

		setTextFieldsConstraints()
		setTextFieldsHidden(imageView.image == nil)
	}

	/**
	Method called from the MemeNavigationController before this view controller is popped of the stack.
	
	At this point, it's still possible to update the on-screen views before taking a snapshot of the
	view hierarchy.
	*/
	func viewControllerIsBeingPopped() {
		if saveOnExit, let meme = meme {
			updateMemeWithCurrentState(nil)
			meme.moveToPermanentStorage()
			MemeList.sharedInstance.saveMeme(meme)
		}
		meme?.cleanTempStorage()
	}

	/**
	When the screen orientation changes:
		* hide text fields before rotation (because their animation is ugly)
	    * hide the keyboard, if present (so that the correct offset view position can be calculated post-rotation)
		* after rotation, if an image is present:
			* adjust the text field constraints
			* show text fields again
	        * show the keyboard again, if it was present before
	
	There's an interesting post that explains how to make this all work even more smoothly,
	but it seems like quite a bit of work, and might change with the next ios version:
		* http://smnh.me/synchronizing-rotation-animation-between-the-keyboard-and-the-attached-view-part-2/
	*/
	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
		let imagePresent = imageView.image != nil
		UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
		println("will rotate", UIDevice.currentDevice().orientation.rawValue)
		isRotating = true
		setTextFieldsHidden(true)
//		let wasActiveTextField = activeTextField
//		activeTextField?.resignFirstResponder()
		coordinator.animateAlongsideTransition(nil, completion: { context in
			println("did rotate", UIDevice.currentDevice().orientation.rawValue)
			self.isRotating = false
			if imagePresent {
				self.setTextFieldsConstraints()
				self.view.setNeedsUpdateConstraints()
				self.view.layoutIfNeeded()
				self.setTextFieldsHidden(false)
//				if let tf = wasActiveTextField {
//					println("wasActiveTextField: \(tf.frame)")
//				}
//				self.activeTextField = wasActiveTextField
//				self.activeTextField?.becomeFirstResponder()
			}
			UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
		})
	}

	@IBAction func pickImage(sender: UIBarButtonItem) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
		self.presentViewController(picker, animated: true, completion: nil)
	}

	@IBAction func takePhoto(sender: UIBarButtonItem) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = UIImagePickerControllerSourceType.Camera
		presentViewController(picker, animated: true, completion: nil)
	}

	@IBAction func shareMeme(sender: UIBarButtonItem) {
		func activityVCFinished(activityType: String!, completed: Bool, returnedItems: [AnyObject]!, error: NSError!) {
			if completed, let meme = meme, let memeImage = shareMemeImage {
				updateMemeWithCurrentState(shareMemeImage)
				// TODO: is this necessary, or does viewControllerIsBeingPopped() handled this:
				meme.moveToPermanentStorage()
				MemeList.sharedInstance.saveMeme(meme)
				navigationController?.popToRootViewControllerAnimated(true)
			}
			shareMemeImage = nil
		}

		if dirtyMeme {
			shareMemeImage = memeAsImage()
		} else {
			// TODO: This could come from temporary storage, too.
			shareMemeImage = meme!.image(.Meme, fromStorageArea: .Permanent)
		}
		if let memeImage = shareMemeImage {
			let activityVC = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
			activityVC.completionWithItemsHandler = activityVCFinished
			self.presentViewController(activityVC, animated: true, completion: nil)
		}
	}


	/**
	Set a flag to not save the meme before popping this VC off the stack.
	*/
	@IBAction func cancelEdit(sender: UIBarButtonItem) {
		saveOnExit = false
		navigationController?.popViewControllerAnimated(true)
	}

	func setTextFieldsHidden(hidden: Bool) {
		topText.hidden = hidden
		bottomText.hidden = hidden
	}

	/**
	Set text field constraints so that they are correctly positioned vertically and of the proper width
	for the image that is currently displayed.
	*/
	func setTextFieldsConstraints() {
		if let image = imageView.image {
			println("setting text field constraints")
			NSLayoutConstraint.deactivateConstraints(textFieldConstraints)
			let margins = imageMargins()
			let verticalInset = margins.verticalMargin + 4
			let textFieldWidth = image.size.width * margins.imageScale - 4
			let topTextYPosition = NSLayoutConstraint(
				item: topText, attribute: .Top,	relatedBy: .Equal, toItem: imageView, attribute: .Top,
				multiplier: 1, constant: verticalInset
			)
			let topTextWidth = NSLayoutConstraint(
				item: topText, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute,
				multiplier: 1, constant: textFieldWidth
			)
			let bottomTextYPosition = NSLayoutConstraint(
				item: bottomText, attribute: .Bottom,	relatedBy: .Equal, toItem: imageView, attribute: .Bottom,
				multiplier: 1, constant: -verticalInset
			)
			let bottomTextWidth = NSLayoutConstraint(
				item: bottomText, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute,
				multiplier: 1, constant: textFieldWidth
			)
			textFieldConstraints = [topTextYPosition, topTextWidth, bottomTextYPosition, bottomTextWidth]
			NSLayoutConstraint.activateConstraints(textFieldConstraints)
		}
	}

	/**
	Returns the margins around the image in the image view.

	Assumes that the image in centered in the image view.
	*/
	func imageMargins() -> (verticalMargin: CGFloat, horizontalMargin: CGFloat, imageScale: CGFloat) {
		var verticalMargin = CGFloat(0)
		var horizontallMargin = CGFloat(0)
		var imageScale = CGFloat(1)
		if let image = imageView.image {
			imageScale = image.scaleToFitInRectOfSize(imageView.frame.size)
			verticalMargin = (imageView.frame.height - image.size.height * imageScale) / 2
			horizontallMargin = (imageView.frame.width - image.size.width * imageScale) / 2
		}
		return (verticalMargin: verticalMargin, horizontalMargin: horizontallMargin, imageScale: imageScale)
	}

	/**
	Style the text fields.
	*/
    func setDefaultTextAttributes() {
        var memeTextAttributes = self.topText.defaultTextAttributes
        memeTextAttributes[NSFontAttributeName] = UIFont(name: "HelveticaNeue-CondensedBlack", size: 40)
        memeTextAttributes[NSForegroundColorAttributeName] = UIColor.whiteColor()
        memeTextAttributes[NSStrokeColorAttributeName] = UIColor.blackColor()
        memeTextAttributes[NSStrokeWidthAttributeName] = -0.3
        memeTextAttributes[NSObliquenessAttributeName] = 0.1
        self.topText.defaultTextAttributes = memeTextAttributes
		self.bottomText.defaultTextAttributes = memeTextAttributes
    }

	/**
	Updates the meme data structure with the current text and meme image.
	*/
	func updateMemeWithCurrentState(var memeImage: UIImage?) {
		if memeImage == nil {
			memeImage = memeAsImage()
		}
		if dirtyMeme, let meme = meme, let image = memeImage {
			meme.topText = topText.text
			meme.bottomText = bottomText.text
			meme.persistMemeImage(image, toStorageArea: .Temporary)
			dirtyMeme = false
		}
	}

	/**
	Captures the memeCanvas (scaled image and text fields) as an image.
	*/
	func memeAsImage() -> UIImage? {
		if let image = imageView.image {

			// Hide the textFieldCursor during snapshot generation
			let oldTextFieldTint = activeTextField?.tintColor
			activeTextField?.tintColor = UIColor.clearColor()

			UIGraphicsBeginImageContextWithOptions(memeCanvas.bounds.size, memeCanvas.opaque, 0.0)
			memeCanvas.drawViewHierarchyInRect(memeCanvas.bounds, afterScreenUpdates: true)
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()

			// Make the text field cursor visible again
			if let oldTint = oldTextFieldTint {
				activeTextField?.tintColor = oldTextFieldTint
			}

			// Crop to remove any blank space around the image.
			let margins = imageMargins()
			let cropRect = imageView.bounds.rectByInsetting(dx: margins.horizontalMargin, dy: margins.verticalMargin)
			return image.crop(cropRect, screenScale: UIScreen.mainScreen().scale)
		}
		return nil
	}

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.

	The repositioning will be animated if ``animationDuration`` and ``animationCurve`` are provided.
	*/
	func ensureActiveTextFieldVisible(#keyboardHeight: CGFloat, keyboardYChange: CGFloat, animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {

		var offset: CGFloat = 0
		if keyboardHeight > 0, let textField = activeTextField {
//			println(textField.frame)
//		if let textField = activeTextField {

//			let keyboardTopY = view.frame.height - keyboardHeight
//			let pic = memeCanvas.convertPoint(CGPoint(x: CGFloat(0), y: keyboardTopY), fromView: nil).y
//			offset = (textField.frame.origin.y + textField.frame.height) - pic

			println("tf frame in kb size handler: \(textField.frame)")

			let textFieldBottomY = textField.convertPoint(CGPoint(x: CGFloat(0), y: textField.bounds.height), toView: nil).y
			let z = memeCanvas.frame.height - textField.convertPoint(CGPoint(x: CGFloat(0), y: textField.bounds.height), toView: memeCanvas).y
			offset = keyboardHeight - z - bottomToolbar.frame.height

//			offset = textFieldBottomY - keyboardTopY
//			offset = max(0, textFieldBottomY - keyboardTopY + bottomToolbar.frame.height + currentCanvasVerticalOffset)

			// textFieldBottomY is the y position
//			let textFieldBottomY = textField.convertPoint(CGPoint(x: CGFloat(0), y: textField.bounds.height), toView: memeCanvas).y - bottomToolbar.frame.height
//			let keyboardTopY = view.convertPoint(CGPoint(x: CGFloat(0), y: view.bounds.height), toView: nil).y - keyboardHeight
//			let adjustment = keyboardTopY - textFieldBottomY + currentCanvasVerticalOffset
//			offset = adjustment

//			if keyboardTopY < textFieldBottomY {
//				offset = currentCanvasVerticalOffset + (textFieldBottomY - keyboardTopY)
//			}


//			if currentCanvasVerticalOffset == 0 {
//				// The keyboard has just appeared.  Calculate how much, if any, it's necessary to move the canvas view
//				// so that the active text field is visible.
//				let textFieldBottomY = memeCanvas.frame.origin.y + textField.frame.origin.y + textField.frame.size.height
//				let keyboardTopY = view.frame.size.height - keyboardHeight
//				if keyboardTopY < textFieldBottomY {
//					offset = currentCanvasVerticalOffset + (textFieldBottomY - keyboardTopY)
//				}
//			} else {
//				// The keyboard did not disappear nor appear, but did change it's height.
//				offset = currentCanvasVerticalOffset - keyboardYChange
//			}
		}

		if offset != currentCanvasVerticalOffset {
			var duration = NSTimeInterval(0)
			var options: UIViewAnimationOptions = .TransitionNone
			if let aDuration = animationDuration, aCurve = animationCurve {
				duration = aDuration
				options = aCurve
			}

			UIView.animateWithDuration(duration, delay: 0.0, options: options, animations: {
				self.setCanvasVConstraintsOffset(offset)
				self.currentCanvasVerticalOffset = offset
				self.view.setNeedsUpdateConstraints()
				}, completion: nil)
		}
	}

	func setCanvasVConstraintsOffset(offset: CGFloat) {
		self.canvasBottomConstraint.constant = offset
		self.canvasTopConstraint.constant = offset
	}


	// MARK: UIImagePickerControllerDelegate methods:

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage, meme = meme {
			imageView.image = image
			let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
			dispatch_async(backgroundQueue, {
				meme.persistOriginalImage(image, toStorageArea: .Temporary)
			})
			setTextFieldsConstraints()
			dirtyMeme = true
        }
        dismissViewControllerAnimated(true, completion: nil)
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK: UITextFieldDelegate methods:

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

	func textFieldDidEndEditing(textField: UITextField) {
		if activeTextField == textField {
			activeTextField = nil
		}
	}

    func textFieldDidBeginEditing(textField: UITextField) {
        activeTextField = textField

		// Clear the text if it's still the default text:
		if (textField == topText && textField.text == "TOP") || (textField == bottomText && textField.text == "BOTTOM") {
			textField.text = ""
			dirtyMeme = true
		}
    }

	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		dirtyMeme = true
		return true
	}


    // MARK: Keyboard notification handlers:

	func keyboardSizeChanging(notification: NSNotification) {
		if isRotating {
			// No need to handle notifications during rotation
			return
		}
		if let userInfo = notification.userInfo as [NSObject: AnyObject]? {
			if let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(),
				let beginFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
					let convertedEndFrame = view.convertRect(endFrame, fromView: view.window)
					let convertedBeginFrame = view.convertRect(beginFrame, fromView: view.window)
					let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double
					let animationOption = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions
					let keyboardHeight = view.bounds.height - convertedEndFrame.origin.y
					let change = convertedEndFrame.height - convertedBeginFrame.height
					ensureActiveTextFieldVisible(keyboardHeight: keyboardHeight, keyboardYChange: change, animationDuration: animationDuration, animationCurve: animationOption)
			}
		}
	}

}