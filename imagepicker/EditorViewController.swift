//
//  EditorViewController.swift
//  imagepicker
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

// TODO perhaps: instead of save in memeeditor, have a cancel button, and auto-save when going back.

class EditorViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoButton: UIBarButtonItem!
    @IBOutlet weak var topText: UITextField!
	@IBOutlet weak var bottomText: UITextField!
    @IBOutlet weak var memeCanvas: UIView!
	@IBOutlet weak var saveButton: UIBarButtonItem!
	@IBOutlet weak var shareButton: UIBarButtonItem!
	@IBOutlet weak var trashButton: UIBarButtonItem!

	var meme: Meme?
    var memeCanvasDefaultCenterY: CGFloat?
    var activeTextField: UITextField?
	var textFieldConstraints = [NSLayoutConstraint]()
	var keyboardHeight: CGFloat = 0
	var isPresentingExistingMeme = false
	var memeTransitionImage: UIImage?  // Image can be specified by pushing controller; will be shown in editor during push animation.

	// Whether or not the meme has been changed since creation or last save:
	var dirtyMeme = false {
		didSet(oldValue) {
			if oldValue != dirtyMeme {
				setActionButtonStatus()
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
	depending on whether or not an image is present, and whether or not the meme has already been saved.
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
		}
		setActionButtonStatus()
		navigationItem.rightBarButtonItems = [saveButton, trashButton, shareButton]
		setTextFieldsHidden(true)
    }

	/**
	When the text in a textbox shrinks, the views are layed out again, and it may be necessary to
	reposition the memeCanvas view to ensure that the text field remains visible.
	*/
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		ensureActiveTextFieldVisible()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		// Record the original center position; this will be useful for calculating the amount to move the view when
		// the keyboard appears, changes size, and disappears.
		if memeCanvasDefaultCenterY == nil {
			memeCanvasDefaultCenterY = memeCanvas.center.y
		}


		if isPresentingExistingMeme {
			isPresentingExistingMeme = false
			if let meme = meme {
				if let image = meme.image(.Source) {
					imageView.image = image.scaledToFitImageView(imageView, withScreenScale:UIScreen.mainScreen().scale)
					memeTransitionImage = nil
				}
			}
		}

		let imagePresent = imageView.image != nil
		if imagePresent {
			setTextFieldsConstraints()
		}
		setTextFieldsHidden(!imagePresent)
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
		self.presentViewController(picker, animated: true, completion: nil)
	}

	@IBAction func saveMeme(sender: UIBarButtonItem) {
		persistMeme()
	}

	@IBAction func shareMeme(sender: UIBarButtonItem) {
		if let memeImage = persistMeme() {
			let activityVC = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
			self.presentViewController(activityVC, animated: true, completion: nil)
		}
	}

	/**
	Deletes the meme and returns to the previous view controller.
	*/
	@IBAction func deleteMeme(sender: UIBarButtonItem) {
		if let meme = meme {
			let alertController = UIAlertController(title: "Delete Meme", message: "It will be gone for good. Are you sure?", preferredStyle: .Alert)
			alertController.addAction(
				UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action: UIAlertAction!) in
					MemeList.sharedInstance.removeMeme(meme)
					self.navigationController?.popToRootViewControllerAnimated(true)
				})
			)
			alertController.addAction(
				UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
			)
			presentViewController(alertController, animated: true, completion: nil)
		}
	}

	func setTextFieldsHidden(hidden: Bool) {
		topText.hidden = hidden
		bottomText.hidden = hidden
	}

	func setActionButtonStatus() {
		let imagePresent = imageView.image != nil
		let memeSaved = meme != nil
		shareButton.enabled = imagePresent
		trashButton.enabled = imagePresent && memeSaved
		saveButton.enabled = imagePresent && dirtyMeme
	}

	/**
	Set text field constraints so that they are correctly positioned vertically and of the proper width
	for the image that is currently displayed.
	*/
	func setTextFieldsConstraints() {
		if let image = imageView.image {
			NSLayoutConstraint.deactivateConstraints(textFieldConstraints)
			let margins = imageMargins()
			let verticalInset = margins.verticalMargin + 4
			let textFieldWidth = image.size.width - 4
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
	func imageMargins() -> (verticalMargin: CGFloat, horizontalMargin: CGFloat) {
		var verticalMargin = CGFloat(0)
		var horizontallMargin = CGFloat(0)
		if let image = imageView.image {
			verticalMargin = (imageView.frame.height - image.size.height) / 2
			horizontallMargin = (imageView.frame.width - image.size.width) / 2
		}
		return (verticalMargin: verticalMargin, horizontalMargin: horizontallMargin)
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
	Saves the meme: writes the images and text to persistent storage.
	*/
	func persistMeme() -> UIImage? {
		if dirtyMeme {
			let memeList = MemeList.sharedInstance
			if let meme = meme {
				meme.topText = topText.text
				meme.bottomText = bottomText.text
			} else {
				meme = Meme(id: nil, topText: topText.text, bottomText: bottomText.text)
			}
			if let meme = meme, original = imageView.image, memeImage = memeAsImage() {
				if memeList.saveMeme(meme, originalImage: original, memeImage: memeImage) {
					dirtyMeme = false
				} else {
					println("Unable to persist meme")
				}
			}
		}
		return meme?.image(.Meme)
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

	func ensureActiveTextFieldVisible() {
		ensureActiveTextFieldVisible(animationDuration: nil, animationCurve: nil)
	}

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.

	The repositioning will be animated if ``animationDuration`` and ``animationCurve`` are provided.
	*/
	func ensureActiveTextFieldVisible(#animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {
		if let textField = activeTextField, let defaultY = memeCanvasDefaultCenterY {
			let textFieldBottomY = memeCanvas.frame.origin.y + textField.frame.origin.y + textField.frame.size.height
			let keyboardTopY = view.frame.size.height - keyboardHeight
			if keyboardTopY < textFieldBottomY {
				var duration = NSTimeInterval(0)
				var options: UIViewAnimationOptions = .TransitionNone
				if let aDuration = animationDuration, aCurve = animationCurve {
					duration = aDuration
					options = aCurve
				}

				UIView.animateWithDuration(duration, delay: 0.0, options: options, animations: {
					self.memeCanvas.center.y = defaultY - (textFieldBottomY - keyboardTopY)
					}, completion: nil)
			}
		}
	}


	// MARK: UIImagePickerControllerDelegate methods:

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
			imageView.image = image.scaledToFitImageView(imageView, withScreenScale:UIScreen.mainScreen().scale)
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
        activeTextField = nil
        return true
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
		if !dirtyMeme {
			dirtyMeme = true
		}
		return true
	}


    // MARK: Keyboard notification handlers:

	func keyboardSizeChanging(notification: NSNotification) {
		keyboardHeight = 0
		if let userInfo = notification.userInfo as [NSObject: AnyObject]? {
			if let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(),
				let beginFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
					let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double
					let animationOption = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions
					keyboardHeight = endFrame.height
			}
		}
		// Let the view know that subviews need to be positioned again.  This will lead to ensureTextFieldVisible() being called.
		view.setNeedsLayout()
	}
}