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

// 解码的速度很快，而渲染的速度稍慢。如果设置的阈值太小，很快缓冲区就会满掉，于是生产者停止生产，阻塞掉；后面，每当消费者消费掉一帧，生产者就会从阻塞态切换回来，生产一个进去，然后继续休眠。这就会导致频繁的线程切换，有较大的开销。在只有视频渲染的时候这种情况还好。但是音视频一起的话，会同时给cpu造成较大的负担，从而导致页面出现卡顿。所以应该设置一个合适的阈值，防止内存暴涨；另外，合理设置视频的帧率，减轻cpu计算的负担。这样我们就能够设置稍微小一点点的阈值
#define QUEUE_CAPACITY 500
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
        std::unique_lock<std::mutex> lg(m_mutex);
        while (m_data.size() >= QUEUE_CAPACITY) {
            m_notFull.wait(lg);
        }
//        m_cond.wait(lg, [this] {return m_data.size() < QUEUE_CAPACITY;});
        m_data.push(data);
        m_notEmpty.notify_one();
    }
    
    void push(DATATYPE && data) {
        std::unique_lock<std::mutex> lg(m_mutex);
        while (m_data.size() >= QUEUE_CAPACITY) {
            m_notFull.wait(lg);
        }
        m_data.push(std::move(data));
        m_notEmpty.notify_one();
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
        m_notEmpty.wait(lg, [this] { return !m_data.empty(); });
        m_data.pop();
        m_notFull.notify_one();
    }
    
private:
    std::queue<DATATYPE, SEQUENCE> m_data;
    mutable std::mutex m_mutex;
    std::condition_variable m_notFull;
    std::condition_variable m_notEmpty;
};
#endif
