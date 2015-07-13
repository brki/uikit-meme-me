//
//  ViewController.swift
//  imagepicker
//
//  Created by Brian on 11/07/15.
//  Copyright (c) 2015 truckin'. All rights reserved.
//

import UIKit


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoButton: UIBarButtonItem!
    @IBOutlet weak var topText: UITextField!
    @IBOutlet weak var wat: UITextField!

    enum TextFieldPosition {
        case Top, Bottom
    }

    let textFieldToImageBorderMargin = CGFloat(10)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        photoButton.enabled = UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)
        self.topText.delegate = self
        setDefaultTextAttributes()

    }

    override func viewWillAppear(animated: Bool) {
        self.topText.hidden = self.imageView.image == nil
    }

    override func viewDidLayoutSubviews() {

        // TODO: maybe it's better to shrink the uiimage view to a reaonable size?
        // Would still need to find that size, but afterwards it might be easier to
        // determine the positions for the text fields.
        if let image = self.imageView.image {
            let scale = imageScale

            let textFieldWidth = CGFloat(max(20, Float(image.size.width) * scale - 20))
            // TODO: adjust width down if image is smaller
            topText.frame.size.width = textFieldWidth

            // TODO: adjust if image is smaller
            let topY = imageView.center.y - (image.size.height * CGFloat(scale)) / 2 + 20
            topText.frame.origin.y = yPositionForTextFieldInPosition(.Bottom, forImage: image, withScale: scale, textField: topText)
            topText.center.x = imageView.center.x
        }

        
    }

    var imageScale: Float {
        get {
            if let image = imageView.image {
                let verticalRatio = Float(imageView.bounds.size.height / image.size.height)
                let horizontalRatio = Float(imageView.bounds.size.width / image.size.width)
                if verticalRatio < 1 || horizontalRatio < 1 {
                    // If either ratio is < 1, the image will be scaled to the smaller of the two ratios.
                    return verticalRatio < horizontalRatio ? verticalRatio : horizontalRatio
                }
            }
            // If no image, or image is smaller than view, no scaling is done.
            return Float(1)
        }
    }

    func yPositionForTextFieldInPosition(position: TextFieldPosition, forImage image: UIImage, withScale scale: Float, textField: UITextField) -> CGFloat{
        var yPosition = imageView.center.y
        let offset = (image.size.height * CGFloat(scale)) / 2
        if position == .Top {
            yPosition -= offset - textFieldToImageBorderMargin
        } else {
            yPosition += offset - textFieldToImageBorderMargin - textField.frame.height
        }
        return yPosition
    }


    func setDefaultTextAttributes() {
        var memeTextAttributes = self.topText.defaultTextAttributes
        memeTextAttributes[NSFontAttributeName] = UIFont(name: "HelveticaNeue-CondensedBlack", size: 40)
        memeTextAttributes[NSForegroundColorAttributeName] = UIColor.whiteColor()
        memeTextAttributes[NSStrokeColorAttributeName] = UIColor.blackColor()
        memeTextAttributes[NSStrokeWidthAttributeName] = -0.3
        memeTextAttributes[NSObliquenessAttributeName] = 0.1
        self.topText.defaultTextAttributes = memeTextAttributes
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

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.imageView.image = image
        }

        dismissViewControllerAnimated(true, completion: nil)
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    // UITextFieldDelegate methods:
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

