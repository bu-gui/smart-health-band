#ifndef MOCK_ARDUINO_H
#define MOCK_ARDUINO_H

#include <iostream>
#include <cmath>
#include <cstdint>
#include <algorithm>

typedef uint8_t byte;

static unsigned long g_mock_millis = 0;
inline unsigned long millis() { return g_mock_millis; }
inline unsigned long micros() { return g_mock_millis * 1000; }
inline void setMockMillis(unsigned long ms) { g_mock_millis = ms; }
inline void advanceMockMillis(unsigned long ms) { g_mock_millis += ms; }

inline void delay(unsigned long ms) { g_mock_millis += ms; }

template <typename T>
inline T constrain(T amt, T low, T high) {
    return (amt < low) ? low : ((amt > high) ? high : amt);
}

#ifndef PI
#define PI 3.14159265358979323846f
#endif

class MockSerial {
public:
    template<typename... Args>
    void printf(const char* fmt, Args... args) {
        // Mock print silent in tests
    }
};

static MockSerial Serial;

#endif
