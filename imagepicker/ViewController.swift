//
//  ViewController.swift
//  imagepicker
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit

// TODO: have a right side navbar menu with possible items: save, delete, share

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoButton: UIBarButtonItem!
    @IBOutlet weak var topText: UITextField!
	@IBOutlet weak var bottomText: UITextField!
    @IBOutlet weak var memeCanvas: UIView!
	@IBOutlet weak var saveButton: UIBarButtonItem!


	var meme: Meme?
    let textFieldToImageBorderMargin = CGFloat(10)
    var memeCanvasDefaultCenterY: CGFloat?
    var activeTextField: UITextField?
	var textFieldConstraints = [NSLayoutConstraint]()
	var keyboardHeight: CGFloat = 0 {
		didSet {
			ensureTextFieldVisible()
		}
	}

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
        notificationCenter.addObserver(self, selector: "keyboardWasShown:", name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		if let image = imageView.image {
			navigationItem.rightBarButtonItems = [saveButton]
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

	func setTextFieldsHidden(hidden: Bool) {
		topText.hidden = hidden
		bottomText.hidden = hidden
	}

	/**
	Set text field constraints so that they are correctly positioned vertically and of the proper width
	for the image that is currently displayed.
	*/
	func setTextFieldsConstraints() {
		NSLayoutConstraint.deactivateConstraints(textFieldConstraints)
		let (scale, scaledSize, vMargin, hMargin) = scaledImageDetails()
		let verticalInset = vMargin + 4
		let textFieldWidth = scaledSize.width - 4
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
			return (scale, imageSize, verticalMargin, horizontallMargin)
		}
		return (1, CGSize(width: 1, height: 1), 0, 0)
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
		let memeList = MemeList.sharedInstance
		if let meme = meme {
			meme.topText = topText.text
			meme.bottomText = bottomText.text
		} else {
			meme = Meme(id: nil, topText: topText.text, bottomText: bottomText.text)
			memeList.list.append(meme!)
		}
		if let meme = meme, original = imageView.image, memeImage = memeAsImage() {
			if !meme.persistImages(original, memeImage: memeImage) {
				println("Unable to persist images")
			}
		}
		memeList.persist()
	}

	func memeAsImage() -> UIImage? {
		if let image = imageView.image {
			UIGraphicsBeginImageContextWithOptions(memeCanvas.bounds.size, memeCanvas.opaque, 0.0)
			memeCanvas.drawViewHierarchyInRect(memeCanvas.bounds, afterScreenUpdates: false)
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return image
		}
		return nil
	}

	/**
	If necessary, repositions the memeCanvas view so that the currently active text field is visible.

	Note that this is called whenever the keyboardHeight property changes.
	*/
	func ensureTextFieldVisible() {
		if let textField = activeTextField, let defaultY = memeCanvasDefaultCenterY {
			let textFieldBottomY = memeCanvas.frame.origin.y + textField.frame.origin.y + textField.frame.size.height
			let keyboardTopY = view.frame.size.height - keyboardHeight
			if keyboardTopY < textFieldBottomY {
				memeCanvas.center.y = defaultY - (textFieldBottomY - keyboardTopY)
			}
		}
	}
	
	// MARK: UIImagePickerControllerDelegate methods:

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.imageView.image = image
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
    }

    // MARK: Keyboard hide/show notification handlers:
	
    func keyboardWasShown(notification: NSNotification) {
		if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
			keyboardHeight = keyboardSize.height
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