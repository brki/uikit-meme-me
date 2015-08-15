//
//  EditorViewController.swift
//  PocketMeme
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
	@IBOutlet weak var shareButton: UIBarButtonItem!
	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet var canvasBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var canvasTopConstraint: NSLayoutConstraint!

	var meme: Meme?
    var activeTextField: UITextField?
	var textFieldConstraints = [NSLayoutConstraint]()
	var keyboardHeight: CGFloat = 0
	var isPresentingExistingMeme = false
	var memeTransitionImage: UIImage?  // Image can be specified by pushing controller; will be shown in editor during push animation.
	var saveOnExit = true

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
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		if isPresentingExistingMeme {
			isPresentingExistingMeme = false
			if let meme = meme {
				if let image = meme.image(.Source) {
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
		if saveOnExit {
			persistMeme()
		}
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
		setTextFieldsHidden(true)
		let wasActiveTextField = activeTextField
		activeTextField?.resignFirstResponder()
		coordinator.animateAlongsideTransition(nil, completion: { context in
			if imagePresent {
				self.setTextFieldsConstraints()
				self.setTextFieldsHidden(false)
				self.activeTextField = wasActiveTextField
				self.activeTextField?.becomeFirstResponder()
			}
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
		self.presentViewController(picker, animated: true, completion: nil)
	}

	@IBAction func shareMeme(sender: UIBarButtonItem) {
		// TODO: beahviour here ... user can cancel share.
		// So: do not persist meme before it returns
		// get meme image
		// present activityVC
		// if canceled:
		//   back to editor
		// else:
		//   save meme and pop to root nav vc
		if let memeImage = persistMeme() {
			let activityVC = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
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

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.

	The repositioning will be animated if ``animationDuration`` and ``animationCurve`` are provided.
	*/
	func ensureActiveTextFieldVisible(#animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {
		var offset: CGFloat = 0
		if keyboardHeight == 0 {
			if currentCanvasVerticalOffset != 0 {
				offset = -currentCanvasVerticalOffset
			}
		} else {
			if let textField = activeTextField {
				let textFieldBottomY = memeCanvas.frame.origin.y + textField.frame.origin.y + textField.frame.size.height
				let keyboardTopY = view.frame.size.height - keyboardHeight
				if keyboardTopY < textFieldBottomY {
					offset = currentCanvasVerticalOffset + (textFieldBottomY - keyboardTopY)
				}
			}
		}
		if offset != currentCanvasVerticalOffset {
			var duration = NSTimeInterval(0)
			var options: UIViewAnimationOptions = .TransitionNone
			if let aDuration = animationDuration, aCurve = animationCurve {
				duration = aDuration
				options = aCurve
			}

			UIView.animateWithDuration(duration, delay: 0.0, options: options, animations: {
				self.canvasBottomConstraint.constant = offset
				self.canvasTopConstraint.constant = offset
				self.currentCanvasVerticalOffset = offset
				//self.view.setNeedsUpdateConstraints()
				}, completion: nil)
		}
	}


	// MARK: UIImagePickerControllerDelegate methods:

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
			imageView.image = image
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

    // MARK: Keyboard notification handlers:

	func keyboardSizeChanging(notification: NSNotification) {
		if let userInfo = notification.userInfo as [NSObject: AnyObject]? {
			if let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(),
				let beginFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
					let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double
					let animationOption = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions
					keyboardHeight = endFrame.height
					ensureActiveTextFieldVisible(animationDuration: animationDuration, animationCurve: animationOption)
			}
		}
	}

}
