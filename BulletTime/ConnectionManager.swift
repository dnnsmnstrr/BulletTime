//
//  ConnectionManager.swift
//  BulletTime
//
//  Created by Dennis Muensterer on 04.06.18.
//  Copyright © 2018 Dennis Muensterer. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol ConnectionManagerDelegate {
    
    func connectedDevicesChanged(manager : ConnectionManager, connectedDevices: [String])
    func receivedImage(manager: ConnectionManager, image: UIImage)
    func receivedRadius(manager: ConnectionManager, radius: Float)
    func receivedData(_ data: Data)

    
}

class ConnectionManager: NSObject {
    
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceType = "bullet-time"
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser : MCNearbyServiceBrowser?
    
    lazy var session : MCSession = {
        let session = MCSession(peer: self.peerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()
    
    var delegate : ConnectionManagerDelegate?
    
    override init() {
        super.init()
        
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        
        self.serviceAdvertiser?.delegate = self
        self.serviceAdvertiser?.startAdvertisingPeer()
        
        self.serviceBrowser?.delegate = self
        self.serviceBrowser?.startBrowsingForPeers()
    }
    
    deinit {
        self.serviceAdvertiser?.stopAdvertisingPeer()
    }
    
    func sendToAllPeers(_ data: Data) {
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("error sending data to peers: \(error.localizedDescription)")
        }
    }

    func send(image : UIImage) {
        NSLog("%@", "sendImage: \(image) to \(session.connectedPeers.count) peers")
        
        if session.connectedPeers.count > 0 {
            do {
                if let imageData = image.pngData() {
                    let data = NSKeyedArchiver.archivedData(withRootObject: imageData)
                    try self.session.send(data, toPeers: session.connectedPeers, with: .reliable)
                    print("sending image")
                }
            }
            catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
        
    }
    
    func sendRadius(radius: Float){
        
        if session.connectedPeers.count > 0 {
            let data = NSKeyedArchiver.archivedData(withRootObject: radius)
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            } catch {
                print("[Error] \(error)")
            }
        }
        
    }
    

}

extension ConnectionManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
    
}

extension ConnectionManager : MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
}

extension ConnectionManager : MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state)")
        self.delegate?.connectedDevicesChanged(manager: self, connectedDevices:
            session.connectedPeers.map{$0.displayName})
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data)")
        
        let object = NSKeyedUnarchiver.unarchiveObject(with: data)
        
//        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
//        unarchiver.requiresSecureCoding = true
//        let object = unarchiver.decodeObject()
//        unarchiver.finishDecoding()
//        print("\(object)")
        
        if object is Float{
            self.delegate?.receivedRadius(manager: self, radius: object as! Float)
        }
        else if object is UIImage{
            self.delegate?.receivedImage(manager: self, image: object! as! UIImage)
        }
        else {
            self.delegate?.receivedData(data)
        }

    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    
}
