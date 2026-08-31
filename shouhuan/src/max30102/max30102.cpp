#include "max30102.h"

/**
 * MAX30102 寄存器地址映射
 *
 * 0x00 - 0x01: 中断状态寄存器
 * 0x02: 中断使能寄存器
 * 0x04: FIFO写指针
 * 0x05: FIFO溢出计数器
 * 0x06: FIFO读指针
 * 0x07: FIFO数据寄存器
 */

/**
 * readRegister - 读取MAX30102单个寄存器（ESP32-S3兼容版本）
 *
 * ESP32-S3的Arduino Wire库对 repeated start (endTransmission(false))
 * 支持不稳定。改用 send STOP + 重新START 模式，兼容性更好。
 */
static uint8_t readRegister(uint8_t reg) {
    Wire.beginTransmission(MAX30102_ADDR);
    Wire.write(reg);
    if (Wire.endTransmission(true) != 0) return 0;
    if (Wire.requestFrom(MAX30102_ADDR, 1) < 1) return 0;
    return Wire.read();
}

/**
 * writeRegister - 写入MAX30102单个寄存器，返回是否成功
 */
static bool writeRegister(uint8_t reg, uint8_t val) {
    Wire.beginTransmission(MAX30102_ADDR);
    Wire.write(reg);
    Wire.write(val);
    return Wire.endTransmission(true) == 0;
}

/**
 * 初始化MAX30102传感器
 *
 * 配置流程：
 * 1. 验证PART_ID确认通信正常
 * 2. 软复位传感器（增加等待时间确保复位完成）
 * 3. 设置SpO2模式(红光+红外同时工作)
 * 4. 配置800Hz采样率，411us脉宽(18位ADC)，16384nA量程
 * 5. 设置红光和红外LED驱动电流
 * 6. 初始化FIFO(启用回绕)和相关状态
 *
 * 注意：I2C速率使用默认100kHz，避免400kHz下手指接触焊盘导致的通信干扰
 *
 * @return true表示初始化成功，false表示I2C通信失败或器件ID不匹配
 */
bool MAX30102Module::begin() {
    Wire.setTimeOut(50); // 设置 50ms 硬件超时保护，防止从机未应答时主线程死锁卡死
    Wire.setClock(100000);
    delay(10);

    // ====== 验证传感器通信 ======
    // 使用独立START/STOP方式（避免ESP32-S3 repeated start问题）
    Wire.beginTransmission(MAX30102_ADDR);
    Wire.write(0xFF);
    if (Wire.endTransmission(true) != 0) {
        Serial.printf("[MAX30102] I2C通信失败（寻址无应答）\n");
        return false;
    }
    if (Wire.requestFrom(MAX30102_ADDR, 1) < 1) {
        Serial.printf("[MAX30102] 读取PART_ID失败，未收到数据\n");
        return false;
    }
    uint8_t partId = Wire.read();
    Serial.printf("[MAX30102] PART_ID=0x%02X (期望0x15)\n", partId);
    if (partId != 0x15) {
        Serial.printf("[MAX30102] PART_ID不匹配，传感器可能未连接或地址错误\n");
        return false;
    }

    // ====== 软复位 ======
    // 设置复位位，等待传感器完全退出复位状态
    writeRegister(0x09, 0x40);
    delay(100);

    // ====== 配置所有寄存器 ======
    bool allWritesOK = true;

    // MODE_CONFIG (0x09): 先配置其他寄存器，MODE_CONFIG最后再设
    // 先设MODE_CONFIG后设其他会导致其他配置被忽略
    // SPO2_CONFIG (0x0A): 采样配置
    // 0x73 = 0b01110011
    //   reserved[7]  = 0
    //   ADC_RGE[6:5] = 11  → 16384nA量程
    //   SPO2_SR[4:2] = 100 → 800Hz采样率
    //   LED_PW[1:0]  = 11  → 411us脉宽(18位分辨率)
    allWritesOK &= writeRegister(0x0A, 0x73);

    // LED1_PA (0x0C): 红光LED电流
    allWritesOK &= writeRegister(0x0C, MAX30102_LED1_CURRENT);

    // LED2_PA (0x0D): 红外LED电流
    allWritesOK &= writeRegister(0x0D, MAX30102_LED2_CURRENT);

    // FIFO_CONFIG (0x08): FIFO配置
    // 0x1F = 0001_1111
    //   SMP_AVE[7:5] = 000 → 1样本/条目（无平均）
    //   FIFO_ROLLOVER_EN[4] = 1 → 启用回绕（满时覆盖旧数据）
    //   FIFO_A_FULL[3:0] = 1111 → 剩余15个空位时触发中断
    allWritesOK &= writeRegister(0x08, 0x1F);

    // MODE_CONFIG (0x09): 最后设置模式，传感器在此刻才开始采样
    allWritesOK &= writeRegister(0x09, 0x03);

    if (!allWritesOK) {
        Serial.printf("[MAX30102] 配置写入失败，传感器可能无法正常工作\n");
    }

    // ====== 验证关键寄存器是否写入成功（诊断输出） ======
    uint8_t modeCheck = readRegister(0x09);
    uint8_t spo2Check = readRegister(0x0A);
    uint8_t fifoCheck = readRegister(0x08);
    uint8_t led1Check = readRegister(0x0C);
    uint8_t led2Check = readRegister(0x0D);

    Serial.printf("[MAX30102] 寄存器验证: MODE=0x%02X SPO2=0x%02X FIFO=0x%02X LED1=0x%02X LED2=0x%02X\n",
        modeCheck, spo2Check, fifoCheck, led1Check, led2Check);

    // 关键检查：MODE必须是0x03，否则传感器没在工作模式
    if (modeCheck != 0x03) {
        Serial.printf("[MAX30102] 错误: MODE_CONFIG=0x%02X，期望0x03！传感器未进入工作模式\n", modeCheck);
        Serial.printf("[MAX30102] 可能原因: I2C写入失败、传感器供电不足、LED_V+未连接\n");
        return false;
    }

    // ====== 重试写入SPO2_CONFIG（部分模块在MODE_CONFIG后需重新写入） ======
    if (spo2Check != 0x73) {
        Serial.printf("[MAX30102] SPO2_CONFIG=0x%02X与期望0x73不符，尝试重写...\n", spo2Check);
        delay(5);
        writeRegister(0x0A, 0x73);
        delay(5);
        spo2Check = readRegister(0x0A);
        if (spo2Check != 0x73) {
            Serial.printf("[MAX30102] SPO2_CONFIG重写后仍为0x%02X（模块可能仅支持400Hz），不影响心率检测\n", spo2Check);
        } else {
            Serial.printf("[MAX30102] SPO2_CONFIG重写成功，采样率800Hz\n");
        }
    }

    // ====== 重置FIFO指针 ======
    for (int reg = 0x04; reg <= 0x06; reg++) {
        writeRegister(reg, 0x00);
    }

    // ====== 中断使能 (0x02) ======
    writeRegister(0x02, 0x01);

    // ====== 初始化内部数据状态 ======
    data.heartRate = 0;
    data.spo2 = 0;
    data.fingerOn = false;
    data.signalQuality = 0;

    bufferIndex = 0;
    lastValidBeatTime = 0;

    irACMax = 0;
    irACMin = 0x3FFFF;

    _filterWarmupCount = 0;
    _isFilterWarmedUp = false;
    _wasFingerOn = false;
    lastFingerOffTime = 0;

    _latestAx = 0;
    _latestAy = 0;
    _latestAz = 0;

    for (int i = 0; i < SAMPLE_COUNT; i++) {
        irBuffer[i] = 0;
        redBuffer[i] = 0;
    }

    return true;
}

/**
 * 更新传感器数据（批量FIFO读取版本）
 *
 * 处理流程：
 * 1. 读取FIFO指针获取可用样本数
 * 2. 批量读取所有可用样本
 * 3. 每个样本经过完整处理链路
 *
 * 关键修复（问题1.4）：
 * - 从单样本读取改为批量读取，避免FIFO溢出
 * - 每次循环读取所有积累的样本，而非仅读1个
 */
void MAX30102Module::update() {
    unsigned long loopStartTime = millis();

    static int i2cErrCount = 0;

    Wire.beginTransmission(MAX30102_ADDR);
    Wire.write(0x04);
    if (Wire.endTransmission(true) != 0) {
        i2cErrCount++;
        if (i2cErrCount > 10) {
            Wire.begin(I2C_SDA, I2C_SCL);
            Wire.setTimeOut(50);
            i2cErrCount = 0;
        }
        return;
    }
    i2cErrCount = 0;

    if (Wire.requestFrom(MAX30102_ADDR, 3) < 3) return;

    uint8_t wrPtr = Wire.read();
    uint8_t ovfCnt = Wire.read();
    uint8_t rdPtr = Wire.read();

    int samplesAvailable = 0;
    if (ovfCnt > 0) {
        samplesAvailable = 32;
    } else {
        samplesAvailable = (wrPtr - rdPtr + 32) % 32;
    }

    // 限制单次最大读取 20 个样本 (120 字节)，防止超越 Wire 库 128 字节接收缓冲区上限
    if (samplesAvailable > 20) {
        samplesAvailable = 20;
    }

    if (samplesAvailable == 0) return;

    int bytesToRead = samplesAvailable * 6;
    Wire.beginTransmission(MAX30102_ADDR);
    Wire.write(0x07);
    if (Wire.endTransmission(true) != 0) return;

    if (Wire.requestFrom(MAX30102_ADDR, bytesToRead) < bytesToRead) return;

    for (int i = 0; i < samplesAvailable; i++) {
        byte redHi = Wire.read();
        byte redMid = Wire.read();
        byte redLo = Wire.read();
        byte irHi = Wire.read();
        byte irMid = Wire.read();
        byte irLo = Wire.read();

        long red = ((long)redHi << 16 | (long)redMid << 8 | redLo) & 0x3FFFF;
        long ir = ((long)irHi << 16 | (long)irMid << 8 | irLo) & 0x3FFFF;

        unsigned long sampleTime = millis();
        processSingleSample(red, ir, sampleTime);
    }
}

/**
 * 处理单个PPG样本（完整处理链路）
 *
 * 数据流：
 * 原始样本 → 异常值过滤 → NLMS运动滤波 → 预热检查 → AC极值追踪
 *   → 环形缓冲区 → 手指检测 → 信号质量 → 心率计算（首次心跳检查）
 *   → SpO2计算（降频）
 *
 * 包含修复：问题1.2/2/3/5/6/7 + 补充1/2/3/4/5/6
 */
void MAX30102Module::processSingleSample(long red, long ir, unsigned long currentTime) {
    // ====== 异常值过滤（问题6 + 补充3） ======
    if (red < 0 || red > 262143 || ir < 0 || ir > 262143) return;

    static long lastValidIr = 0, lastValidRed = 0;
    if (lastValidIr > 0 && abs(ir - lastValidIr) > 50000) {
        ir = lastValidIr;  // 异常突变，使用上次有效值
    } else if (ir > 1000) {
        lastValidIr = ir;
    }
    if (lastValidRed > 0 && abs(red - lastValidRed) > 50000) {
        red = lastValidRed;
    } else if (red > 1000) {
        lastValidRed = red;
    }

    // ====== NLMS运动伪影滤波（始终执行以更新权重—问题5 预热） ======
    long irFiltered = motionFilter.process(ir, _latestAx, _latestAy, _latestAz);

    // ====== 预热检查（问题5） ======
    // 预热期间滤波器权重从0开始收敛，跳过心率血氧计算
    // 但滤波器的process()已经在上方调用并更新了权重
    if (!_isFilterWarmedUp) {
        _filterWarmupCount++;
        if (_filterWarmupCount >= 200) {
            _isFilterWarmedUp = true;
            Serial.printf("[MAX30102] 运动滤波器预热完成 (200样本)\n");
        }
        return;
    }

    // ====== 更新AC信号特征（补充1：修正后的纯衰减逻辑） ======
    irACMax = (long)(irACMax * 0.998f);   // 仅指数衰减
    irACMin = (long)(irACMin * 0.998f);
    if (ir > irACMax) irACMax = ir;       // 硬比较捕获新极值
    if (ir < irACMin) irACMin = ir;

    // ====== 数据存入环形缓冲区 ======
    irBuffer[bufferIndex] = ir;
    redBuffer[bufferIndex] = red;
    bufferIndex = (bufferIndex + 1) % SAMPLE_COUNT;

    // ====== 手指放置检测 ======
    data.fingerOn = fingerDetect.detect(ir, red, irACMax, irACMin);

    // ====== 手指OFF→ON跳变：轻量重置DC滤波器，保留心跳时序 ======
    if (data.fingerOn && !_wasFingerOn) {
        unsigned long offDuration = currentTime - lastFingerOffTime;
        if (lastFingerOffTime == 0 || offDuration > 2000) {
            hrAlgo.reset(ir);
        }
        irACMax = ir;
        irACMin = ir;
    } else if (!data.fingerOn && _wasFingerOn) {
        lastFingerOffTime = currentTime;
        lastValidBeatTime = currentTime;
    }
    _wasFingerOn = data.fingerOn;

    // ====== 信号质量评估（问题4：周期性检测已在SignalQuality内部实现） ======
    if (!data.fingerOn) {
        data.signalQuality = 0;
    } else {
        data.signalQuality = sigQuality.evaluate(irBuffer, SAMPLE_COUNT);
    }

    if (data.fingerOn) {
        // ====== 心率计算（首次心跳检查） ======
        if (hrAlgo.checkForBeat(ir)) {
            long lastBeat = hrAlgo.getLastBeatTime();
            if (lastBeat != 0) {  // 非首次心跳才计算心率
                long delta = currentTime - lastBeat;
                int hr = hrAlgo.calculateHeartRate(delta);
                // SQI保护：仅在信号质量 >= 20 时才更新心率，防止剧烈甩手伪影破坏有效心率
                if (hr > 0 && data.signalQuality >= 20) {
                    data.heartRate = hr;
                }
            }
            hrAlgo.setLastBeatTime(currentTime);
            lastValidBeatTime = currentTime;
        }

        // ====== 血氧计算 ======
        // 每100ms且在缓冲区满一圈时计算一次，避免高频浪费CPU
        static unsigned long lastSpO2CalcTime = 0;
        if (millis() - lastSpO2CalcTime >= 100 && bufferIndex == 0) {
            data.spo2 = spo2Algo.calculateFromBuffer(redBuffer, irBuffer, SAMPLE_COUNT, true);
            lastSpO2CalcTime = millis();
        }
    } else {
        // ====== 手指移开超时重置（问题3：完全重置） ======
        if (lastValidBeatTime != 0 && (currentTime - lastValidBeatTime > NO_FINGER_TIMEOUT)) {
            data.heartRate = 0;
            data.spo2 = 0;
            hrAlgo.reset();
            fingerDetect.reset();
            motionFilter.reset();

            // 重置滤波器预热状态
            _filterWarmupCount = 0;
            _isFilterWarmedUp = false;

            irACMax = 0;
            irACMin = 0x3FFFF;
            bufferIndex = 0;
            lastValidBeatTime = 0;

            for (int i = 0; i < SAMPLE_COUNT; i++) {
                irBuffer[i] = 0;
                redBuffer[i] = 0;
            }
        }
    }
}

/**
 * 设置加速度数据
 * 由主循环调用，传入MPU6050最新加速度值用于运动伪影滤波
 *
 * 注意：建议确保调用频率不低于PPG采样率（见补充6）
 *
 * @param ax X轴加速度(g)
 * @param ay Y轴加速度(g)
 * @param az Z轴加速度(g)
 */
void MAX30102Module::setAccelData(float ax, float ay, float az) {
    _latestAx = ax;
    _latestAy = ay;
    _latestAz = az;
}

/**
 * 获取最新的健康数据
 * @return HealthData结构体，包含心率、血氧、手指状态和信号质量
 */
MAX30102Module::HealthData MAX30102Module::getData() {
    return data;
}
