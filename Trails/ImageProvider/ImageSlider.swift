import Foundation
import UIKit

class ImageSlider {
	
	private let trails: [Trail]
	private let displayImageCallback: (UIImage -> Void)
	private let completionCallback: (Void -> Void)
	
	private var images = [UIImage]()
	private var waitingForImage = 0
	private var currentShowingImage = -1
	
	init(trails: [Trail]!, displayImageCallback: (UIImage -> Void), completionCallback: (Void -> Void)) {
		self.trails = trails
		self.displayImageCallback = displayImageCallback
		self.completionCallback = completionCallback
	}
	
	func start() {
		let trailsUrls = self.trails.map(trailsToUrls)
		let imagesProvider = ImagesProvider(imagePaths: trailsUrls, imageDownloadedCallback: imageDownloadedCallback)
		imagesProvider.provide()
	}
	
	private func imageDownloadedCallback(index: Int, image: UIImage) {
		print("Downloaded image at index \(index)")
		images.append(image)
		
		if index == waitingForImage {
			currentShowingImage++
			displayImageCallback(image)
		}
	}
	
	private func trailsToUrls(trail: Trail) -> String {
		return trail.mediaPath
	}
	
	func next() {
		currentShowingImage++
		
		if isFinished() {
			completionCallback()
			return
		}
		
		if isCurrentImageLoaded() {
			displayImageCallback(images[currentShowingImage])
		} else {
			waitingForImage = currentShowingImage
			displayImageCallback(UIImage(named: "overlay_skip")!)
		}
	}
	
	private func isFinished() -> Bool {
		return currentShowingImage == trails.count
	}
	
	private func isCurrentImageLoaded() -> Bool {
		return currentShowingImage <= images.count - 1
	}
}