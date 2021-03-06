//
//  EditorViewController.swift
//  PocketMeme
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit
import CoreData

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
	var isNewMeme = false

	var mainObjectContext: NSManagedObjectContext!

	// Whether or not the meme has been changed since creation or last save:
	var dirtyMeme = false {
		didSet(oldValue) {
			if oldValue != dirtyMeme {
				cancelButton.enabled = dirtyMeme
			}
		}
	}

	// MARK: VC lifecycle: 

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
	Ensure that the appropriate elements are shown or hidden, depending on whether or not an image is present.

	If not already present, initialize self.meme.
	*/
    override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		if isPresentingExistingMeme {
			if let passedInMeme = meme {
				if let image = memeTransitionImage {
					imageView.image = image
					memeTransitionImage = nil
				}
				topText.text = passedInMeme.topText
				bottomText.text = passedInMeme.bottomText
			}
		} else {
			if meme == nil {
				isNewMeme = true
                meme = Meme(id: nil, topText: topText.text ?? "", bottomText: bottomText.text ?? "", managedObjectContext: mainObjectContext)
			}
		}
		cancelButton.enabled = dirtyMeme
		shareButton.enabled = imageView.image != nil
		navigationItem.rightBarButtonItems = [cancelButton, shareButton]

		// Hide the text fields during the animation, they will be shown if needed in viewDidAppear.
		setTextFieldsHidden(true)
    }
    
	/**
	Set the image from the meme, if presenting an existing meme.  If applicable, set the text field constraints.
	*/
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		if isPresentingExistingMeme {
			isPresentingExistingMeme = false
			if let meme = meme {
				if let image = meme.image(.Source) {
					imageView.image = image
				}
			}
		}

		setTextFieldsConstraints()
		setTextFieldsHidden(imageView.image == nil)
	}

	/**
	Method called from the MemeNavigationController before this view controller is popped off the stack.
	
	At this point, it's still possible to update the on-screen views before taking a snapshot of the
	view hierarchy.
	*/
	func viewControllerIsBeingPopped() {
		if let meme = meme {
			if saveOnExit && dirtyMeme {
				persistMemeWithImage(meme, image: nil)
			} else if isNewMeme {
				mainObjectContext.deleteObject(meme)
			} else {
				mainObjectContext.refreshObject(meme, mergeChanges: false)
			}
		}
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

	// MARK: Storyboard actions

	/**
	Pick an image from the photo album.
	*/
	@IBAction func pickImage(sender: UIBarButtonItem) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
		self.presentViewController(picker, animated: true, completion: nil)
	}

	/**
	Take a photo to use as a meme.
	*/
	@IBAction func takePhoto(sender: UIBarButtonItem) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = UIImagePickerControllerSourceType.Camera
		presentViewController(picker, animated: true, completion: nil)
	}

	/**
	Presents an activity view controller.
	
	If the activity view controller was not cancelled by the user, pop back to the navigation controller's root.
	*/
	@IBAction func shareMeme(sender: UIBarButtonItem) {

		var shareMemeImage: UIImage?
		if dirtyMeme {
			shareMemeImage = memeAsImage()
		} else {
			shareMemeImage = meme!.image(.Meme)
		}
		if let memeImage = shareMemeImage {
			let activityVC = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
			activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
				if completed, let meme = self.meme, let memeImage = shareMemeImage {
					self.persistMemeWithImage(meme, image: memeImage)
					self.navigationController?.popToRootViewControllerAnimated(true)
				}
			}
			self.presentViewController(activityVC, animated: true, completion: nil)
		}
	}

	/**
	Set a flag to not save the meme, and pop this VC off the stack.
	*/
	@IBAction func cancelEdit(sender: UIBarButtonItem) {
		saveOnExit = false
		navigationController?.popViewControllerAnimated(true)
	}

	/**
	Hide keyboard if user taps outside of active text field.
	*/
	@IBAction func viewTapped(sender: UITapGestureRecognizer) {
		if let textField = activeTextField {
			textField.resignFirstResponder()
		}
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
			bottomTextWidthConstraint.constant = textFieldWidth
			topTextTopToImageViewTopConstraint.constant = verticalInset
			bottomTextBottomToImageViewBottomConstraint.constant = verticalInset
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
        
        let memeImage = image ?? memeAsImage()
        if dirtyMeme, let image = memeImage {
            meme.topText = topText.text ?? ""
            meme.bottomText = bottomText.text ?? ""
            meme.setImage(image, forType:Meme.ImageType.Meme)
            meme.generateThumbnails(image)
        }
		// TODO: perhaps move this somewhere else: Meme?  MemeList?:
        mainObjectContext.performBlockAndWait {
            do {
                try self.mainObjectContext.save()
				guard let context = self.mainObjectContext.parentContext else {
					print("Not able to get parent context when saving")
					return
				}
				context.performBlock {
					do {
						try context.save()
					} catch let error as NSError {
						print("Error persisting to permanent store when saving: \(error)")
					}
				}
            } catch let error as NSError {
                print("Error saving child context in persistMemeWithImage(): \(error)")
            }
        }
        dirtyMeme = false
	}

	/**
	Captures the memeCanvas (scaled image and text fields) as an image.
	*/
	func memeAsImage() -> UIImage? {
		if imageView.image != nil {

			// Hide the textFieldCursor during snapshot generation
			let oldTextFieldTint = activeTextField?.tintColor
			activeTextField?.tintColor = UIColor.clearColor()

			UIGraphicsBeginImageContextWithOptions(memeCanvas.bounds.size, memeCanvas.opaque, 0.0)
			memeCanvas.drawViewHierarchyInRect(memeCanvas.bounds, afterScreenUpdates: true)
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()

			// Make the text field cursor visible again
			if let oldTint = oldTextFieldTint {
				activeTextField?.tintColor = oldTint
			}

			// Crop to remove any blank space around the image.
			let margins = imageMargins()
			let cropRect = imageView.bounds.insetBy(dx: margins.horizontalMargin, dy: margins.verticalMargin)
			return image.crop(cropRect, screenScale: UIScreen.mainScreen().scale)
		}
		return nil
	}


	// MARK: UIImagePickerControllerDelegate methods:

	/**
	When an image has been picked, set the imageView image and adjust text field constraints.
	
	Save the picked image to persistent storage, using a background thread so that the UI is not blocked waiting for that.
	*/
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage, meme = meme {
			imageView.image = image            
            mainObjectContext.performBlockAndWait {
                meme.setImage(image, forType:Meme.ImageType.Source)
            }
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
			if let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() {
				let convertedEndFrame = view.convertRect(endFrame, fromView: view.window)
				let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double
				let animationOption = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions
				let keyboardHeight = view.bounds.height - convertedEndFrame.origin.y
				ensureActiveTextFieldVisible(keyboardHeight: keyboardHeight, animationDuration: animationDuration, animationCurve: animationOption)
			}
		}
	}

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.
	
	After rotation, the text field's frame will not be correct unless it's constraints have been updated, and self.view's constraints
	and layout have been updated (see viewWillTransitionToSize() implementation).
	*/
	func ensureActiveTextFieldVisible(keyboardHeight keyboardHeight: CGFloat, animationDuration: NSTimeInterval?, animationCurve: UIViewAnimationOptions?) {

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

			UIView.animateWithDuration(duration, delay: 0.0, options: options, animations: {
				self.canvasBottomConstraint.constant = offset
				self.canvasTopConstraint.constant = offset
				self.currentCanvasVerticalOffset = offset
				self.view.setNeedsUpdateConstraints()
				}, completion: nil)
		}
	}
}