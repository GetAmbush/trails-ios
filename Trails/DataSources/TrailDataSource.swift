import Foundation
import Koloda

class TrailDataSource: KolodaViewDataSource {
    
    var trails = [Trail]()
    
    func kolodaNumberOfCards(koloda: KolodaView) -> UInt {
        return UInt(trails.count)
    }
    
    func kolodaViewForCardAtIndex(koloda: KolodaView, index: UInt) -> UIView {
        let cardView = getViewFromNibNamed("CardView") as! CardView
        
        print("Hey, card for index ->>> \(index)")
        cardView.render(trails[Int(index)])
        return cardView
    }
    
    func kolodaViewForCardOverlayAtIndex(koloda: KolodaView, index: UInt) -> OverlayView? {
        return getViewFromNibNamed("CustomOverlayView") as? OverlayView
    }
    
    
    func fetchNext(success: Void -> Void, failure: Void -> Void) {
        Trail.nextEvaluation { (trails: [Trail]?, errorType: ErrorType?) -> Void in

            if errorType != nil {
                print(errorType.debugDescription)
                failure()
                return
            }
            
            self.trails += trails!

            success()
        }
    }
    
    
    private func getViewFromNibNamed(name: String) -> UIView {
        return NSBundle.mainBundle().loadNibNamed(name, owner: nil, options: nil)[0] as! UIView
    }    
}