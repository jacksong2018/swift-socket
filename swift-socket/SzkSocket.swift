//
//  SzkSocket.swift
//  luyin
//
//  Created by sss on 2018/3/31.
//  Copyright © 2018年 pom0o. All rights reserved.
//

import Foundation
import Darwin

public class SzkSocket{
    
    public static let SOCKET_MINIMUM_READ_BUFFER_SIZE = 1024
    public static let SOCKET_DEFAULT_READ_BUFFER_SIZE = 4096
    
    var mServerAddr: String!
    var mServerPort: String!
    
    var mServerAddrInfo: UnsafeMutablePointer<addrinfo>?
    
    var mSockFd: Int32! = -1
    
    var isConnected: Bool! = false
    var remoteConnectionClosed: Bool! = false
    
    var readBuffer: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: SzkSocket.SOCKET_DEFAULT_READ_BUFFER_SIZE)
    
    var readBufferSize: Int = SzkSocket.SOCKET_DEFAULT_READ_BUFFER_SIZE {
        
        // If the buffer size changes we need to reallocate the buffer...
        didSet {
            
            // Ensure minimum buffer size...
            if readBufferSize < SzkSocket.SOCKET_MINIMUM_READ_BUFFER_SIZE {
                
                readBufferSize = SzkSocket.SOCKET_MINIMUM_READ_BUFFER_SIZE
            }
            
            if readBufferSize != oldValue {
                readBuffer.deinitialize(count: readBufferSize)
                readBuffer.deallocate()
                readBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: readBufferSize)
                readBuffer.initialize(repeating: 0, count: readBufferSize)
            }
        }
    }
    
    //var processFunc: (_ data: UnsafeMutablePointer<CChar>, _ length: Int) -> Void = nil
    
    public init(){
        // Get the info we need to create our socket descriptor
        
    }
    
    public init(_ serverAddr: String!,_ serverPort: Int!){
        mServerAddr = serverAddr
        mServerPort = String(serverPort)
        
    }
    
    func setServerAddr(_ serverAddr: String!){
        mServerAddr = serverAddr
        
    }
    
    func setServerPort(_ serverPort: in_port_t!){
        mServerPort = String(serverPort)
    }
    
    func start(processReceivedData: @escaping (String,Int) -> Void){
        let concurrent = DispatchQueue(label: "readQueue", attributes: .concurrent)
        concurrent.async {
            self.connect(processReceivedData)
        }
    }
    
    private func connect(_ processReceivedData: @escaping (String,Int) -> Void) {
        
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)
        
        var status: Int32 = Darwin.getaddrinfo(mServerAddr, mServerPort, &hints, &mServerAddrInfo)
        
        if status != 0 {
            
              var errorString: String
            if status == EAI_SYSTEM {
                errorString = String(validatingUTF8: strerror(errno)) ?? "Unknown error code."
            } else {
                errorString = String(validatingUTF8: gai_strerror(status)) ?? "Unknown error code."
            }
            print("SzkSocket: connect error \(errorString)")
        }
        
        var info = mServerAddrInfo
        
        while info != nil {

            mSockFd = Darwin.socket(info!.pointee.ai_family, info!.pointee.ai_socktype, info!.pointee.ai_protocol)
            if mSockFd == -1 {
                print("SzkSocket: connect  mSockFd == -1")
                continue
            }
            
            print("Connect to the server... ")
            
            status = Darwin.connect(mSockFd!, info!.pointee.ai_addr, info!.pointee.ai_addrlen)
            
            // Break if successful...
            if status == 0 {
                isConnected = true
                print("Connect to the server successful")
                break
            }
            sleep(1)
            print("Connect to the server again")
            Darwin.close(mSockFd!)
            mSockFd = -1
            info = info?.pointee.ai_next
        }
        
    }
    
    func wrtie(string: String) -> Int {
        if string.isEmpty || string.count == 0 {
            return -1
        }
        
        var res: Int = -1
        
        let concurrent = DispatchQueue(label: "writeQueue", attributes: .concurrent)
        concurrent.async {
            res = string.utf8CString.withUnsafeBufferPointer() {
                // The count returned by nullTerminatedUTF8 includes the null terminator...
                return self.write(from: $0.baseAddress!, bufSize: $0.count-1)
            }
        }
        return res
    }
    
    private func write(from buffer: UnsafeRawPointer, bufSize: Int) -> Int {
        // Make sure the buffer is valid...
        if bufSize == 0 {
            print("SzkSocket: write bufSize error")
            return -1
        }
        
        // The socket must've been created and must be connected...
        if self.mSockFd == -1 {
            print("SzkSocket: write mSockFd invalid")
            return -2
        }
        
        if !self.isConnected {
            print("SzkSocket: write socket not connect")
            return -3
        }
        
        var sent = 0
        let sendFlags: Int32 = 0

        while sent < bufSize {
            
            var s = 0

            s = Darwin.send(self.mSockFd, buffer.advanced(by: sent), Int(bufSize - sent), sendFlags)
            
            if s <= 0 {
                
                if errno == EAGAIN {
                    // We have written out as much as we can...
                    print("SzkSocket: write non-blocking sent \(sent)")
                    return sent
                }
                
                // - Handle a connection reset by peer (ECONNRESET) and throw a different exception...
                if errno == ECONNRESET {
                    print("SzkSocket: write error SOCKET_ERR_CONNECTION_RESET")
                    cleanUpSocket()
                    return -4
                }
            }
            sent += s
        }
        
        return sent
    }
    
    private func readData(_ processReceivedData: @escaping (String,Int) -> Void){
        
        // The socket must've been created and must be connected...
        if self.mSockFd == -1 {
            print("SzkSocket: readData mSockFd invalid")
            return
        }
        
        if !self.isConnected {
            print("SzkSocket: readData socket not connect")
            return
        }
        
        self.readDataLoop(processReceivedData)
        
    }
    
    private func readDataLoop(_ processReceivedData: @escaping (String,Int) -> Void) {
        readBuffer.initialize(repeating: 0x0, count: readBufferSize)
        // Read all the available data...
        
        let recvFlags: Int32 = 0

        //recvFlags |= Int32(MSG_DONTWAIT)
        
        var count: Int = 0
        repeat {
    
            count = Darwin.recv(self.mSockFd, self.readBuffer, self.readBufferSize, recvFlags)
                
            // Check for error...
            if count < 0 {
                
                switch errno {
                    
                    // - Could be an error, but if errno is EAGAIN or EWOULDBLOCK (if a non-blocking socket),
                    //    it means there was NO data to read...
                    case EAGAIN:
                        print("SzkSocket: readData error EAGAIN")
                        fallthrough
                    case EWOULDBLOCK:
                        print("SzkSocket: readData error EAGAIN, return read loop")
                        return
                    
                    case ECONNRESET:
                        // - Handle a connection reset by peer (ECONNRESET) and throw a different exception...
                        print("SzkSocket: readData error EAGAIN")
                        cleanUpSocket()
                    default:
                        // - Something went wrong...
                        print("SzkSocket: readData error UNKNOWN")
                }
                
            }
            
            if count == 0 {
                self.remoteConnectionClosed = true
                print("SzkSocket: readData socket Closed by remoteConnection, return read loop")
                cleanUpSocket()
                return
            }
            
            // proccess the data in the buffer...
            processReceivedData(String(cString: self.readBuffer), count)
            
            // Didn't fill the buffer so we've got everything available...
            
        } while count > 0
    }
    
    private func cleanUpSocket(){
        shutdown(mSockFd, SHUT_RDWR)
        close(mSockFd)
        self.isConnected = false
        self.mSockFd = -1
    }

    
}


