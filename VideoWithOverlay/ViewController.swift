//
//  ViewController.swift
//  VideoWithOverlay
//
//  Created by Aurélie Nouaille-Degorce on 02/06/2019.
//  Copyright © 2019 Nouaille-Degorce. All rights reserved.
//
// I used https://www.raywenderlich.com/5135-how-to-play-record-and-merge-videos-in-ios-and-swift to help me merge videos.

import UIKit
import AVFoundation
import MobileCoreServices
import Photos

class ViewController: UIViewController {
    
    struct Constant {
        // This is how much Overlay square represents versus the video height
        static let percentageOverlayVsVideo: CGFloat = 0.8
        
        // Color for all overlay texts
        static let overlayTextsColor = UIColor.yellow.cgColor
        
        // Vertical section of overlay dedicated to personName
        static let verticalPercentPersonName: CGFloat = 0.22
        
        // Vertical section of overlay dedicated to part one text
        static let verticalPercentForPartOne: CGFloat = 0.22
        
        // Vertical section of overlay dedicated to part two text
        static let verticalPercentForPartTwo: CGFloat = 0.22
        
        // Vertical section of overlay dedicated to bottom texts
        static let verticalPercentBottomTexts: CGFloat = 0.34
        
        // In bottom texts, horizontal section of overlay dedicated to main bottom text (for work place)
        static let bottomHorizontalRightPart: CGFloat = 0.92
    }
    
    var firstVideoURL: URL?
    var secondVideoURL: URL?
    
    var firstAsset: AVAsset?
    var secondAsset: AVAsset?
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var informationLabel: UILabel!
    
    func exportDidFinish(_ session: AVAssetExportSession) {
        
        activityIndicator.stopAnimating()
        firstAsset = nil
        secondAsset = nil
        
        guard session.status == AVAssetExportSession.Status.completed,
            let outputURL = session.outputURL else { return }
        
        let saveVideoToPhotos = {
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL) }) { saved, error in
                let success = saved && (error == nil)
                let title = success ? "Success" : "Error"
                let message = success ? "Video saved" : "Failed to save video"
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        // Ensure permission to access Photo Library
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                if status == .authorized {
                    saveVideoToPhotos()
                }
            })
            print("New video should be saved in Photo Library if user accepts")
        } else {
            saveVideoToPhotos()
            print("New video should be saved in Photo Library")
        }
    }
    
    
    @IBAction func exportMergedVideoWithOverlay(_ sender: UIButton) {
        informationLabel.text = "Merged video export is requested"
        guard firstVideoURL != nil, secondVideoURL != nil else { return }
        firstAsset = AVAsset(url: firstVideoURL!)
        secondAsset = AVAsset(url: secondVideoURL!)
        
        activityIndicator.startAnimating()
        
        // 1 - Create AVMutableComposition object. This object will hold the AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        
        // 2 - Create two video tracks
        guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video,
                                                              preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
        do {
            try firstTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAsset!.duration),
                                           of: firstAsset!.tracks(withMediaType: .video)[0],
                                           at: CMTime.zero)
        } catch {
            print("Failed to load first track")
            informationLabel.text = "Failed to load first track"
            return
        }
        
        guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video,
                                                               preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
        do {
            try secondTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAsset!.duration),
                                            of: secondAsset!.tracks(withMediaType: .video)[0],
                                            at: firstAsset!.duration)
        } catch {
            print("Failed to load second track")
            informationLabel.text = "Failed to load second track"
            return
        }
        
        // Create AVMutableVideoCompositionInstruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTimeAdd(firstAsset!.duration, secondAsset!.duration))
        
        let firstInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstTrack)
//        let firstInstruction = VideoHelper.videoCompositionInstruction(firstTrack, asset: firstAsset!)
        firstInstruction.setOpacity(0.0, at: firstAsset!.duration)
        let secondInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: secondTrack)
//        let secondInstruction = VideoHelper.videoCompositionInstruction(secondTrack, asset: secondAsset!)
        
        // Add instructions
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        let videoSize = secondTrack.naturalSize
        mainComposition.renderSize = videoSize
//        mainComposition.renderSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        // 3 - I should add overlay animation
        
//        let videoSize = secondTrack.naturalSize.applying(secondTrack.preferredTransform)
        
        let overlaySide = Constant.percentageOverlayVsVideo * min(videoSize.width, videoSize.height)
        
        let topLayer = CATextLayer()
        topLayer.frame = CGRect.init(x: 0,
                                     y: overlaySide * (1 - Constant.verticalPercentPersonName),
                                     width: overlaySide,
                                     height: overlaySide * Constant.verticalPercentPersonName)
        topLayer.fontSize = 105
        topLayer.alignmentMode = .center
        topLayer.string = TextPartsForOverlay.init().personName
        topLayer.isWrapped = true
        topLayer.foregroundColor = Constant.overlayTextsColor
        
        let partOneLayer = CATextLayer()
        partOneLayer.frame = CGRect.init(x: 0,
                                         y: overlaySide * (1 - Constant.verticalPercentPersonName - Constant.verticalPercentForPartOne),
                                         width: overlaySide,
                                         height: overlaySide * Constant.verticalPercentForPartOne)
        partOneLayer.fontSize = 90
        partOneLayer.alignmentMode = .center
        partOneLayer.string = TextPartsForOverlay.init().partOne
        partOneLayer.isWrapped = true
        partOneLayer.foregroundColor = Constant.overlayTextsColor
        
        let partTwoLayer = CATextLayer()
        partTwoLayer.frame = CGRect.init(x: 0,
                                         y: overlaySide * Constant.verticalPercentBottomTexts,
                                         width: overlaySide,
                                         height: overlaySide * Constant.verticalPercentForPartTwo)
        partTwoLayer.fontSize = 105
        partTwoLayer.alignmentMode = .center
        partTwoLayer.string = TextPartsForOverlay.init().partTwo
        partTwoLayer.isWrapped = true
        partTwoLayer.foregroundColor = Constant.overlayTextsColor
        
        let bottomLeftLayer = CATextLayer()
        bottomLeftLayer.frame = CGRect.init(x: 0,
                                            y: 0,
                                            width: overlaySide * (1 - (Constant.bottomHorizontalRightPart * 1.03)),
                                            height: overlaySide * Constant.verticalPercentBottomTexts)
        bottomLeftLayer.fontSize = 40
        bottomLeftLayer.alignmentMode = .natural
        bottomLeftLayer.string = "C H E Z"
        bottomLeftLayer.isWrapped = true
        bottomLeftLayer.foregroundColor = Constant.overlayTextsColor
        
        let bottomMainLayer = CATextLayer()
        bottomMainLayer.frame = CGRect.init(x: overlaySide * (1 - Constant.bottomHorizontalRightPart),
                                            y: 0,
                                            width: overlaySide * Constant.bottomHorizontalRightPart,
                                            height: overlaySide * Constant.verticalPercentBottomTexts * 0.8)
        bottomMainLayer.fontSize = 77
        bottomMainLayer.alignmentMode = .center
        bottomMainLayer.string = TextPartsForOverlay.init().workPlace
        bottomMainLayer.isWrapped = true
        bottomMainLayer.foregroundColor = Constant.overlayTextsColor
        
        
        let overlayLayer = CALayer()
        overlayLayer.addSublayer(topLayer)
        overlayLayer.addSublayer(partOneLayer)
        overlayLayer.addSublayer(partTwoLayer)
        overlayLayer.addSublayer(bottomLeftLayer)
        overlayLayer.addSublayer(bottomMainLayer)
        
        overlayLayer.frame = CGRect.init(x: 0.5*(videoSize.width - overlaySide),
                                         y: 0.5*(videoSize.height - overlaySide),
                                         width: videoSize.width,
                                         height: videoSize.height)
//        overlayLayer.masksToBounds = true

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        mainComposition.animationTool = AVVideoCompositionCoreAnimationTool.init(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        
        // TODO: I should use CABasicAnimation to animate sequences and include them in the overlay layers.
        
        // 4 - Get path
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
        informationLabel.text = "Export is going to be created: the new video should be in your Photo Library soon"
        
        // 5 - Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition
        
        // 6 - Perform the Export
        exporter.exportAsynchronously() {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter)
            }
        }
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        firstVideoURL = Bundle.main.url(forResource: "countdown", withExtension: "mov")
        secondVideoURL = Bundle.main.url(forResource: "bunny", withExtension: "mp4")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
    }


}

