//
//  ViewController.swift
//  imagepicker
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

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
    let textFieldToImageBorderMargin = CGFloat(10)
    var memeCanvasDefaultCenterY: CGFloat?
    var activeTextField: UITextField?
	var textFieldConstraints = [NSLayoutConstraint]()
	var keyboardHeight: CGFloat = 0
	var dirtyMeme = false  // Whether or not the meme has been changed since creation or last save.

    enum TextFieldPosition {
        case Top, Bottom
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        photoButton.enabled = UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)
        topText.delegate = self
		bottomText.delegate = self
        setDefaultTextAttributes()

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "keyboardWasShown:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }

	/**
	Ensure that the appropriate elements are shown or hidden, and that the text fields are appropriately sized,
	depending on whether or not an image is present, and whether or not the meme has already been saved.
	*/
    override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		setActionButtonStatus()
		navigationItem.rightBarButtonItems = [saveButton, trashButton, shareButton]
		if let image = imageView.image {
			setTextFieldsHidden(false)
			setTextFieldsConstraints()
		} else {
			setTextFieldsHidden(true)
		}
    }

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		// When the text in a textbox shrinks, the views are layed out again, and it may be necessary to
		// reposition the view to ensure that the text field remains visible.
		ensureTextFieldVisible()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		// Record the original center position; this will be useful for calculating the amount to move the view when
		// the keyboard appears, changes size, and disappears.
		if memeCanvasDefaultCenterY == nil {
			memeCanvasDefaultCenterY = memeCanvas.center.y
		}
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
					self.navigationController?.popViewControllerAnimated(true)
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
		let memeSaved = meme?.id != nil
		shareButton.enabled = imagePresent
		trashButton.enabled = imagePresent && memeSaved
		saveButton.enabled = imagePresent && dirtyMeme
	}

	/**
	Set text field constraints so that they are correctly positioned vertically and of the proper width
	for the image that is currently displayed.
	*/
	func setTextFieldsConstraints() {
		NSLayoutConstraint.deactivateConstraints(textFieldConstraints)
		let scaleInfo = scaledImageDetails()
		let verticalInset = scaleInfo.verticalMargin + 4
		let textFieldWidth = scaleInfo.imageSize.width - 4
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

	/**
	Returns the scaled size of the image, and the vertical and horizon margins (i.e. the space between
	the edge of the image and the edge of the image view).
	*/
	func scaledImageDetails() -> (scale: CGFloat, imageSize: CGSize, verticalMargin: CGFloat, horizontalMargin: CGFloat) {
		if let image = imageView.image {
			let scale = imageScale
			let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
			let verticalMargin = (imageView.frame.height - imageSize.height) / 2
			let horizontallMargin = (imageView.frame.width - imageSize.width) / 2
			return (scale: scale, imageSize: imageSize, verticalMargin: verticalMargin, horizontalMargin: horizontallMargin)
		}
		return (scale: 1, imageSize: CGSize(width: 1, height: 1), verticalMargin: 0, horizontalMargin: 0)
	}

	/**
	The scale that has been applied to the image to fit in the image view
	*/
    var imageScale: CGFloat {
		if let image = imageView.image {
			let verticalRatio = imageView.frame.size.height / image.size.height
			let horizontalRatio = imageView.frame.size.width / image.size.width
			// If either ratio is < 1, the image will be scaled to the smaller of the two ratios.
			return min(1, min(verticalRatio, horizontalRatio))
		}
		// If no image no scaling is done:
		return 1
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
					// Delete button should be active:
					setActionButtonStatus()
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
			UIGraphicsBeginImageContextWithOptions(memeCanvas.bounds.size, memeCanvas.opaque, 0.0)
			memeCanvas.drawViewHierarchyInRect(memeCanvas.bounds, afterScreenUpdates: false)
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()

			// Crop to remove any blank space around the image.
			let info = scaledImageDetails()
			let cropRect = imageView.bounds.rectByInsetting(dx: info.horizontalMargin, dy: info.verticalMargin)
			return image.crop(cropRect)
		}
		return nil
	}

	func ensureTextFieldVisible() {
		ensureTextFieldVisible(animationDuration: nil, animationCurve: nil)
	}

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.

	The repositioning will be animated if ``animationDuration`` and ``animationCurve`` are provided.
	*/
	func ensureTextFieldVisible(#animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {
		if let textField = activeTextField, let defaultY = memeCanvasDefaultCenterY {
			let textFieldBottomY = memeCanvas.frame.origin.y + textField.frame.origin.y + textField.frame.size.height
			let keyboardTopY = view.frame.size.height - keyboardHeight
			if keyboardTopY < textFieldBottomY {
				if let duration = animationDuration, curve = animationCurve {
					UIView.animateWithDuration(duration, delay: 0.0, options: curve, animations: {
						self.memeCanvas.center.y = defaultY - (textFieldBottomY - keyboardTopY)
					}, completion: nil)
				} else {
					self.memeCanvas.center.y = defaultY - (textFieldBottomY - keyboardTopY)
				}
			}
		}
	}
	
	// MARK: UIImagePickerControllerDelegate methods:

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.imageView.image = image
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
		dirtyMeme = true
		return true
	}

    // MARK: Keyboard hide/show notification handlers:

    func keyboardWasShown(notification: NSNotification) {
		if let userInfo = notification.userInfo as [NSObject: AnyObject]? {
			if let keyboardSize = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() {
				keyboardHeight = keyboardSize.height
				let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double
				let animationOption = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions
				ensureTextFieldVisible(animationDuration: animationDuration, animationCurve: animationOption)
			}
		} else {
			keyboardHeight = 0
		}
    }

    func keyboardWillHide(notification: NSNotification) {
		if let y = memeCanvasDefaultCenterY {
			if y != memeCanvas.center.y {
				memeCanvas.center.y = y
			}
		}
		keyboardHeight = 0
    }
}