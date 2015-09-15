import UIKit
import SwiftyDropbox
import Koloda
import pop
import ObjectMapper

private let frameAnimationSpringBounciness:CGFloat = 9
private let frameAnimationSpringSpeed:CGFloat = 16

class HomeViewController: UIViewController, KolodaViewDataSource, KolodaViewDelegate {
    
    @IBOutlet weak var kolodaView: TrailView!
    @IBOutlet weak var toggleDropboxLink: UIBarButtonItem!
    
    var image: UIImage!
    var trails = [Trail]()
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if verifyDropboxAuthorization() {
            evaluateTrails()
        }
    }
    
    func evaluateTrails() {
        Trail.nextEvaluation { (trails: [Trail]?, errorType: ErrorType?) -> Void in
            if errorType != nil {
                print(errorType.debugDescription)
                return
            }
            self.trails += trails!
            self.showTrails()
        }
    }
    
    func showTrails() {
        kolodaView.delegate = self
        kolodaView.dataSource = self
        kolodaView.alphaValueSemiTransparent = 0.1
        kolodaView.countOfVisibleCards = 2
        self.modalTransitionStyle = UIModalTransitionStyle.FlipHorizontal
    }
    
    func thumbNailFor(path: String, completionHandler: ((UIImage) -> Void)) {
        Dropbox.authorizedClient?.filesGetThumbnail(path: path, size: Files.ThumbnailSize.W1024h768).response { response, error in
            if let (metadata, data) = response {
                print("Download files name: \(metadata.name)")
                completionHandler(UIImage(data: data)!)
            } else {
                print(error!)
            }
        }
        
    }
    
    @IBAction func leftButtonTapped() {
        kolodaView?.swipe(SwipeResultDirection.Left)
    }
    
    @IBAction func rightButtonTapped() {
        kolodaView?.swipe(SwipeResultDirection.Right)
    }
    
    @IBAction func undoButtonTapped() {
        kolodaView?.revertAction()
    }
    
    //MARK: KolodaViewDataSource
    func kolodaNumberOfCards(koloda: KolodaView) -> UInt {
        return UInt(self.trails.count)
    }
    
    func kolodaViewForCardAtIndex(koloda: KolodaView, index: UInt) -> UIView {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .ScaleAspectFit
        let trail = self.trails[Int(index)]
        
        thumbNailFor(trail.mediaPath) { (image: UIImage) -> Void in
            imageView.image = image
        }
        
        return imageView
    }
    func kolodaViewForCardOverlayAtIndex(koloda: KolodaView, index: UInt) -> OverlayView? {
        return NSBundle.mainBundle().loadNibNamed("CustomOverlayView",
            owner: self, options: nil)[0] as? OverlayView
    }
    
    func kolodaDidSwipedCardAtIndex(koloda: KolodaView, index: UInt, direction: SwipeResultDirection) {
    }
    
    func kolodaDidRunOutOfCards(koloda: KolodaView) {
        evaluateTrails()
    }
    
    func kolodaDidSelectCardAtIndex(koloda: KolodaView, index: UInt) {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://yalantis.com/")!)
    }
    
    func kolodaShouldApplyAppearAnimation(koloda: KolodaView) -> Bool {
        return true
    }
    
    func kolodaShouldMoveBackgroundCard(koloda: KolodaView) -> Bool {
        return false
    }
    
    func kolodaShouldTransparentizeNextCard(koloda: KolodaView) -> Bool {
        return false
    }
    
    func kolodaBackgroundCardAnimation(koloda: KolodaView) -> POPPropertyAnimation? {
        let animation = POPSpringAnimation(propertyNamed: kPOPViewFrame)
        animation.springBounciness = frameAnimationSpringBounciness
        animation.springSpeed = frameAnimationSpringSpeed
        return animation
    }
    
    func verifyDropboxAuthorization() ->  Bool {
        if let authorizedClient = Dropbox.authorizedClient {
            
            let dropboxAccessTokens = DropboxAuthManager.sharedAuthManager.getAllAccessTokens().keys

            if dropboxAccessTokens.count > 0 {
                toggleDropboxLink.title = "Unlink from Dropbox"
                
                let userId = dropboxAccessTokens.reverse().first!
                let authToken = DropboxAuthManager.sharedAuthManager.getAccessToken(userId)
                
                Account.instance.registerDropbox(userId, accessToken: authToken!.description)
                authorizedClient.usersGetCurrentAccount().response { response, error in
                    if let account = response {
                        Account.instance.update(account)
                    } else {
                        print(error!)
                    }
                }
                
                return true
            } else {
                Dropbox.unlinkClient()
                sleep(1)
                return verifyDropboxAuthorization()
            }
        }
        toggleDropboxLink.title = "Link with Dropbox"
        return false
    }
    
    @IBAction func didTapDropboxLink(sender: AnyObject) {
        if let _ = Dropbox.authorizedClient {
            Dropbox.unlinkClient()
            verifyDropboxAuthorization()
        } else {
           Dropbox.authorizeFromController(self)
        }
    }
    
    @IBAction func linkButtonPressed(sender: AnyObject) {
        if (Dropbox.authorizedClient == nil) {
            Dropbox.authorizeFromController(self)
        } else {
            print("User is already authorized!")
        }
    }
}