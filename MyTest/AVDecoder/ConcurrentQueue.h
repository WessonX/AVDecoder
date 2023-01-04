//
//  ConcurrentQueue.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/4.
//

#ifndef __CONCURRENCEQUEUE_H__
#define __CONCURRENCEQUEUE_H__
#include <mutex>
#include <condition_variable>
#include <deque>
#include <queue>
#include <memory>

template<typename DATATYPE, typename SEQUENCE = std::deque<DATATYPE>>
class ConcurrenceQueue {
public:
        typedef typename std::queue<DATATYPE>::size_type size_type;
        typedef typename std::queue<DATATYPE>::reference reference;
        typedef typename std::queue<DATATYPE>::const_reference const_reference;

    ConcurrenceQueue() = default;
    
    ConcurrenceQueue(const ConcurrenceQueue & other) {
        std::lock_guard<std::mutex> lg(other.m_mutex);
        m_data = other.m_data;
    }
    ConcurrenceQueue(ConcurrenceQueue &&) = delete;
    ConcurrenceQueue & operator= (const ConcurrenceQueue &) = delete;
    ~ConcurrenceQueue() = default;
    bool empty() const {
        std::lock_guard<std::mutex> lg(m_mutex);
        return m_data.empty();
    }
    
    void push(const DATATYPE & data) {
        std::lock_guard<std::mutex> lg(m_mutex);
        m_data.push(data);
        m_cond.notify_one();
    }
    
    void push(DATATYPE && data) {
        std::lock_guard<std::mutex> lg(m_mutex);
        m_data.push(std::move(data));
        m_cond.notify_one();
    }

    reference front(){
        std::lock_guard<std::mutex> lg(m_mutex);
        return m_data.front();
    }

    size_type size(){
        std::lock_guard<std::mutex> lg(m_mutex);
        return m_data.size();
    }
    
    void tryPop() {  // 非阻塞
        std::lock_guard<std::mutex> lg(m_mutex);
        if (m_data.empty()) return;
        m_data.pop();
        return ;
    }
    
    void pop() {  // 非阻塞
        std::unique_lock<std::mutex> lg(m_mutex);
        m_cond.wait(lg, [this] { return !m_data.empty(); });
        m_data.pop();
        return;
    }
    
private:
    std::queue<DATATYPE, SEQUENCE> m_data;
    mutable std::mutex m_mutex;
    std::condition_variable m_cond;
};
#endif
