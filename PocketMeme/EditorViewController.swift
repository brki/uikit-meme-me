//
//  EditorViewController.swift
//  PocketMeme
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

// TODO: tap outside of firstresponder closes keyboard.

import UIKit

class EditorViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoButton: UIBarButtonItem!
    @IBOutlet weak var topText: UITextField!
	@IBOutlet weak var bottomText: UITextField!
    @IBOutlet weak var memeCanvas: UIView!
	@IBOutlet weak var shareButton: UIBarButtonItem!
	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet weak var bottomToolbar: UIToolbar!

	@IBOutlet weak var canvasBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var canvasTopConstraint: NSLayoutConstraint!
	@IBOutlet weak var topTextWidthConstraint: NSLayoutConstraint!
	@IBOutlet weak var topTextTopToImageViewTopConstraint: NSLayoutConstraint!
	@IBOutlet weak var bottomTextWidthConstraint: NSLayoutConstraint!
	@IBOutlet weak var bottomTextBottomToImageViewBottomConstraint: NSLayoutConstraint!

	var meme: Meme?  // Pushing VC can set this if an existing meme should be used.
	var activeTextField: UITextField?  // Text field currently being edited.
	var isPresentingExistingMeme = false  // Pushing VC can set this if an existing meme should be used.
	var memeTransitionImage: UIImage?  // Image can be specified by pushing controller; will be shown in editor during push animation.
	var saveOnExit = true
	var isRotating = false
	var currentCanvasVerticalOffset: CGFloat = 0  // Keeps track of the canvas constraint offset, to see if the constraints need to be changed when KB size notifications handled.

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
			persistMemeWithImage(meme, image: nil)
		}
		meme?.cleanTempStorage()
	}

	/**
	When the screen orientation changes:
		* hide text fields before rotation (because their animation is ugly)
		* after rotation, if an image is present:
			* adjust the text field constraints
			* show text fields again

	There's an interesting post that explains how to make this all work even more smoothly,
	but it seems like quite a bit of work, and might change with the next ios version:
		* http://smnh.me/synchronizing-rotation-animation-between-the-keyboard-and-the-attached-view-part-2/
	*/
	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
		let imagePresent = imageView.image != nil
		isRotating = true
		setTextFieldsHidden(true)
		coordinator.animateAlongsideTransition(nil, completion: { context in
			self.isRotating = false
			if imagePresent {
				// It is necessary to follow this order so that the textField's frame positions
				// are correct when the post-rotation UIKeyboardWillChangeFrameNotification is received:
				// 1. set constraints, 2. setNeedsUpdateConstraints, 3. layoutIfNeeded.
				self.setTextFieldsConstraints()
				self.view.setNeedsUpdateConstraints()
				self.view.layoutIfNeeded()
				self.setTextFieldsHidden(false)
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
		presentViewController(picker, animated: true, completion: nil)
	}

	@IBAction func shareMeme(sender: UIBarButtonItem) {

		var shareMemeImage: UIImage?
		if dirtyMeme {
			shareMemeImage = memeAsImage()
		} else {
			// TODO: This could come from temporary storage, too?
			shareMemeImage = meme!.image(.Meme, fromStorageArea: .Permanent)
		}
		if let memeImage = shareMemeImage {
			let activityVC = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
			activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
				if completed, let meme = self.meme, let memeImage = shareMemeImage {
					self.persistMemeWithImage(meme, image: shareMemeImage)
					self.navigationController?.popToRootViewControllerAnimated(true)
				}
			}
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
			let margins = imageMargins()
			let verticalInset = margins.verticalMargin + 4
			let textFieldWidth = image.size.width * margins.imageScale - 4
			topTextWidthConstraint.constant = textFieldWidth
			topTextTopToImageViewTopConstraint.constant = verticalInset
			bottomTextWidthConstraint.constant = textFieldWidth
			bottomTextBottomToImageViewBottomConstraint.constant = -verticalInset
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
	Persists the meme and all it's images to permanent storage.
	If no image is provided, an image is generated from the current imageView and text fields.
	*/
	func persistMemeWithImage(meme: Meme, image: UIImage? = nil) {
		updateMemeWithCurrentState(nil)
		meme.moveToPermanentStorage()
		MemeList.sharedInstance.saveMeme(meme)
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
	func ensureActiveTextFieldVisible(#keyboardHeight: CGFloat, animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {

		var offset: CGFloat = 0
		if keyboardHeight > 0, let textField = activeTextField {
			let textFieldRelativeBottom = textField.convertPoint(CGPoint(x: CGFloat(0), y: textField.bounds.height), toView: memeCanvas).y
			let textFieldRelativeOffset = memeCanvas.frame.height - textFieldRelativeBottom
			offset = max(0, keyboardHeight - textFieldRelativeOffset - bottomToolbar.frame.height)
		}

		if offset != currentCanvasVerticalOffset {
			var duration = NSTimeInterval(0)
			var options: UIViewAnimationOptions = .TransitionNone
			if let aDuration = animationDuration, aCurve = animationCurve {
				duration = aDuration
				options = aCurve
			}

			// TODO: would be nice if this animates after rotation: it doesn't seem to:

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
					ensureActiveTextFieldVisible(keyboardHeight: keyboardHeight, animationDuration: animationDuration, animationCurve: animationOption)
			}
		}
	}

}