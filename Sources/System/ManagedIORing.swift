final public class ManagedIORing: @unchecked Sendable {
    var internalRing: IORing

    init(queueDepth: UInt32) throws {
        self.internalRing = try IORing(queueDepth: queueDepth)
        self.startWaiter()        
    }

    private func startWaiter() {
        Task.detached {
            while (!Task.isCancelled) {
                let cqe = self.internalRing.blockingConsumeCompletion()

                let cont = unsafeBitCast(cqe.userData, to: UnsafeContinuation<IOCompletion, Never>.self)
                cont.resume(returning: cqe)
            }
        }
    }

    @_unsafeInheritExecutor
    public func submitAndWait(_ request: __owned IORequest) async -> IOCompletion {
        self.internalRing.submissionMutex.lock()
        return await withUnsafeContinuation { cont in
            let entry = internalRing._blockingGetSubmissionEntry()
            entry.pointee = request.rawValue
            entry.pointee.user_data = unsafeBitCast(cont, to: UInt64.self)
            self.internalRing._submitRequests()
            self.internalRing.submissionMutex.unlock()
        }
    }


}