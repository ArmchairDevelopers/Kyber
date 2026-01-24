// Copyright Armchair Developers. Licensed under GPLv3.

#pragma once

#include <Core/Memory.h>
#include <Base/Log.h>

#include <grpcpp/grpcpp.h>


namespace Kyber
{

class GenericAsyncClientCall
{
public:
    virtual ~GenericAsyncClientCall() = default;
    virtual void Process(bool ok) = 0;
};

template<typename Request, typename Response>
class AsyncClientCall : public GenericAsyncClientCall
{
public:
    using Callback = std::function<void(const Response*, grpc::Status)>;

    grpc::ClientContext m_context;
    grpc::Status m_status;
    Response m_response;
    std::unique_ptr<grpc::ClientAsyncResponseReader<Response>> m_responseReader;
    Callback m_callback;

    void Process(bool ok) override
    {
        if (m_callback == nullptr)
        {
            return;
        }

        // if `ok` is false, call failed before completion
        if (ok)
        {
            m_callback(&m_response, m_status);
        }
        else
        {
            m_callback(nullptr, grpc::Status(grpc::StatusCode::UNKNOWN, "Async call failed"));
        }
    }
};

class AsyncRPCManager
{
public:
    template<typename Request, typename Response, typename Stub>
    void StartCall(Stub* stub,
        std::unique_ptr<grpc::ClientAsyncResponseReader<Response>> (Stub::*prepareAsyncMethod)(
            grpc::ClientContext*, const Request&, grpc::CompletionQueue*),
        const Request& request, typename AsyncClientCall<Request, Response>::Callback callback,
        const std::map<std::string, std::string>& headers = {})
    {
        void* callPtr = FB_GLOBAL_ARENA->alloc(sizeof(AsyncClientCall<Request, Response>));
        AsyncClientCall<Request, Response>* call = new (callPtr) AsyncClientCall<Request, Response>;
        call->m_callback = std::move(callback);

        for (const auto& [key, value] : headers)
        {
            call->m_context.AddMetadata(key, value);
        }

        call->m_responseReader = (stub->*prepareAsyncMethod)(&call->m_context, request, &m_cq);
        call->m_responseReader->StartCall();
        call->m_responseReader->Finish(&call->m_response, &call->m_status, call);
    }

    void Update() const;

private:
    mutable grpc::CompletionQueue m_cq;
};
} // namespace Kyber