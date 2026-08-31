#include "mock_arduino.h"
#include <cassert>
#include <iostream>

// 零修改零入侵包含原始固件核心源码
#include "../src/mpu6050/motion.h"
#include "../src/mpu6050/motion.cpp"
#include "../src/max30102/algorithm.h"
#include "../src/max30102/algorithm.cpp"

void testScene1A_PedometerShake() {
    std::cout << "[RUNNING] 场景 1A: 甩手防误触测试 (伪造 2 次 0.3g 抖动)..." << std::endl;
    setMockMillis(1000);
    Pedometer ped;

    // 晃手 1 下 (波峰 0.30g)
    ped.update(0.10f); advanceMockMillis(50);
    ped.update(0.30f); advanceMockMillis(50);
    ped.update(0.05f); advanceMockMillis(50);

    assert(ped.getSteps() == 0 && "甩手1下累计步数必须为 0");
    assert(ped.getCandidateSteps() == 1 && "甩手1下候选步数应为 1");

    advanceMockMillis(400); // 间隔 400ms

    // 晃手 2 下 (波峰 0.30g)
    ped.update(0.10f); advanceMockMillis(50);
    ped.update(0.30f); advanceMockMillis(50);
    ped.update(0.05f); advanceMockMillis(50);

    assert(ped.getSteps() == 0 && "甩手2下累计步数必须保持 0");
    assert(ped.getCandidateSteps() == 2 && "甩手2下候选步数应为 2");

    // 停顿 >3000ms
    advanceMockMillis(3500);
    ped.update(0.01f);

    assert(ped.getSteps() == 0 && "停顿>3s后累计步数依然为 0");
    assert(ped.getCandidateSteps() == 0 && "停顿>3s后候选步数必须被清零");
    assert(!ped.isEstablished() && "步态确认状态必须为 false");

    std::cout << "  [PASS] 场景 1A 成功通过！晃手 2 下加 0 步，停顿 >3s 候选步自动清零。" << std::endl;
}

void testScene1B_PedometerWalking() {
    std::cout << "[RUNNING] 场景 1B: 连续迈步补齐测试 (伪造连续 5 次 0.3g 行走波峰)..." << std::endl;
    setMockMillis(1000);
    Pedometer ped;

    for (int step = 1; step <= 5; step++) {
        ped.update(0.05f); advanceMockMillis(50);
        ped.update(0.15f); advanceMockMillis(50);
        bool stepRet = ped.update(0.30f); advanceMockMillis(50);
        if (ped.update(0.05f)) stepRet = true; advanceMockMillis(50);

        advanceMockMillis(300); // 迈步间隔 500ms

        if (step < 3) {
            assert(!stepRet && "前 2 次候选迈步 update 应返回 false");
            assert(ped.getSteps() == 0 && "前 2 次迈步累计步数维持 0");
        } else if (step == 3) {
            assert(stepRet && "第 3 步应触发补齐，update 返回 true");
            assert(ped.getSteps() == 3 && "第 3 步完成后，一次性补齐前 3 步");
            assert(ped.isEstablished() && "步态确认建立 isEstablished == true");
        } else {
            assert(ped.getSteps() == step && "建立步态后每一步实时 +1");
        }
    }

    assert(ped.getSteps() == 5 && "连续 5 步后总步数必须精确为 5");
    std::cout << "  [PASS] 场景 1B 成功通过！连续 5 步第 3 步触发补齐，最终精确为 5 步。" << std::endl;
}

void testScene2A_SQI_ColdStart() {
    std::cout << "[RUNNING] 场景 2A: SQI 首帧直达冷启动测试..." << std::endl;
    setMockMillis(1000);
    SignalQuality sq;

    long buffer[32];
    for (int i = 0; i < 32; i++) {
        buffer[i] = 100000 + (long)(1500.0f * sinf(i * 0.2f)); // ratio ~ 3.0% -> raw 80
    }

    int score = sq.evaluate(buffer, 32);
    assert(score == 80 && "首帧 SQI 输出必须直达 80 (无从 0 慢爬延迟)");
    std::cout << "  [PASS] 场景 2A 成功通过！首帧输出 = " << score << " (直达 80，冷启动保护生效)。" << std::endl;
}

void testScene2B_SQI_Smoothing() {
    std::cout << "[RUNNING] 场景 2B: SQI 交替 10/80 级别的 EMA 平滑防跳变测试..." << std::endl;
    setMockMillis(1000);
    SignalQuality sq;

    long highQualityBuffer[32];
    long lowQualityBuffer[32];
    for (int i = 0; i < 32; i++) {
        highQualityBuffer[i] = 100000 + (long)(1500.0f * sinf(i * 0.2f)); // ratio ~ 3.0% -> raw 80
        lowQualityBuffer[i] = 100000 + (long)(10.0f * sinf(i * 0.2f));   // ratio ~ 0.02% -> raw 10
    }

    // 首帧建立基线
    sq.evaluate(highQualityBuffer, 32);

    bool hasSawtoothDropTo20 = false;
    int lastScore = 0;
    for (int i = 0; i < 20; i++) {
        int score = 0;
        if (i % 2 == 0) {
            score = sq.evaluate(lowQualityBuffer, 32);
        } else {
            score = sq.evaluate(highQualityBuffer, 32);
        }
        if (score < 20) {
            hasSawtoothDropTo20 = true;
        }
        lastScore = score;
    }

    assert(!hasSawtoothDropTo20 && "EMA 平滑后输出绝不应跌落至 <20 的锯齿低谷");
    assert(lastScore >= 25 && lastScore <= 85 && "平滑输出稳定收敛在 25~85 区间");
    std::cout << "  [PASS] 场景 2B 成功通过！EMA 滤波完全平滑锯齿，极值收敛 = " << lastScore << " (无 <20 的跌落)。" << std::endl;
}

int main() {
    std::cout << "========================================" << std::endl;
    std::cout << "   固件核心算法纯 C++ 本地仿真测试集" << std::endl;
    std::cout << "========================================" << std::endl;

    testScene1A_PedometerShake();
    testScene1B_PedometerWalking();
    testScene2A_SQI_ColdStart();
    testScene2B_SQI_Smoothing();

    std::cout << "========================================" << std::endl;
    std::cout << " ALL FIRMWARE ALGORITHM TESTS 100% PASS!" << std::endl;
    std::cout << "========================================" << std::endl;
    return 0;
}
