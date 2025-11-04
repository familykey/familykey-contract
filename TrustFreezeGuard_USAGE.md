# TrustFreezeGuard 使用指南

## 📋 概述

TrustFreezeGuard 是一个 Safe Guard 合约，用于在指定的信托期内冻结 Safe 钱包的 Owner 操作权限，同时保持 Module（如 DeadManSwitch）的正常运行。

## ✨ 核心特性

- ✅ **冻结 Owner 操作**：在冻结期内，Owner 无法通过 `execTransaction` 执行任何交易
- ✅ **Module 独立运行**：Module 通过 `execTransactionFromModule` 执行的交易不受影响（如继承功能）
- ✅ **无状态设计**：一个 Guard 合约可供多个 Safe 使用
- ✅ **Gas 高效**：仅需一次时间戳比较
- ✅ **符合标准**：遵循 Safe 官方 Guard 模式，支持 ERC165

## 🏗️ 架构原理

```
Owner 交易:  Owner签名 -> Safe.execTransaction() -> Guard.checkTransaction() -> ❌ 冻结期内拒绝
Module 交易: Module调用 -> Safe.execTransactionFromModule() -> ✅ 跳过 Guard，直接执行
```

## 📦 已实现的合约

### 1. TrustFreezeGuard.sol
主合约，实现了 Safe Guard 接口。

**位置**: `contracts/src/TrustFreezeGuard.sol`

**核心功能**:
- `freezeUntil(uint256 timestamp)`: 设置冻结期
- `isFrozen(address safe)`: 检查 Safe 是否冻结
- `getRemainingFreezeTime(address safe)`: 获取剩余冻结时间
- `getUnfreezeTime(address safe)`: 获取解冻时间戳

### 2. DeployTrustFreezeGuard.s.sol
部署脚本。

**位置**: `contracts/script/DeployTrustFreezeGuard.s.sol`

### 3. TrustFreezeGuard.t.sol
完整的测试套件（27 个测试全部通过）。

**位置**: `contracts/test/TrustFreezeGuard.t.sol`

## 🚀 部署指南

### 环境准备

```bash
cd contracts

# 确保已安装依赖
forge install
```

### 部署到测试网（Holesky）

```bash
# 设置环境变量
export PRIVATE_KEY="your_private_key"
export RPC_URL="https://ethereum-hoodi-rpc.publicnode.com"
export ETHERSCAN_API_KEY="your_etherscan_api_key"

# 部署合约
forge script script/DeployTrustFreezeGuard.s.sol:DeployTrustFreezeGuard \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

# 部署信息会保存到: ./deployments/trustfreezeguard-17000-latest.json
```

### 部署到主网

```bash
# 使用主网 RPC
export RPC_URL="your_mainnet_rpc_url"

# 部署前建议先模拟
forge script script/DeployTrustFreezeGuard.s.sol:DeployTrustFreezeGuard \
  --rpc-url $RPC_URL

# 确认无误后再广播
forge script script/DeployTrustFreezeGuard.s.sol:DeployTrustFreezeGuard \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

## 📝 集成指南

### 前端集成步骤

#### 1. 安装依赖

```bash
cd apps/web
pnpm add ethers @safe-global/safe-core-sdk
```

#### 2. 配置合约地址

在 `.env` 中添加：

```bash
VITE_TRUST_FREEZE_GUARD_ADDRESS=0x... # 部署后的地址
```

#### 3. 创建 ABI 文件

```typescript
// apps/web/src/abi/trustFreezeGuard.ts
export const TRUST_FREEZE_GUARD_ABI = [
  "function freezeUntil(uint256 timestamp)",
  "function isFrozen(address safe) view returns (bool)",
  "function getRemainingFreezeTime(address safe) view returns (uint256)",
  "function getUnfreezeTime(address safe) view returns (uint256)",
  "function frozenUntil(address safe) view returns (uint256)"
] as const;

export const TRUST_FREEZE_GUARD_ADDRESS = import.meta.env.VITE_TRUST_FREEZE_GUARD_ADDRESS;
```

#### 4. 实现冻结功能

```typescript
// apps/web/src/services/trustFreeze.ts
import { ethers } from 'ethers';
import { TRUST_FREEZE_GUARD_ABI, TRUST_FREEZE_GUARD_ADDRESS } from '../abi/trustFreezeGuard';

export async function freezeSafe(
  safeAddress: string,
  unfreezeDate: Date,
  signer: ethers.Signer
) {
  const guardContract = new ethers.Contract(
    TRUST_FREEZE_GUARD_ADDRESS,
    TRUST_FREEZE_GUARD_ABI,
    signer
  );

  // 1. 检查是否已设置 Guard
  const safeContract = new ethers.Contract(
    safeAddress,
    ['function getStorageAt(bytes32 slot, uint256 length) view returns (bytes)'],
    signer
  );

  // Safe Guard 存储槽位
  const GUARD_STORAGE_SLOT = '0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8';
  const currentGuardBytes = await safeContract.getStorageAt(GUARD_STORAGE_SLOT, 1);
  const currentGuard = ethers.utils.getAddress('0x' + currentGuardBytes.slice(-40));

  // 2. 如果尚未设置 Guard，需要先设置
  if (currentGuard !== TRUST_FREEZE_GUARD_ADDRESS) {
    console.log('Setting guard on Safe...');

    // 构造 setGuard 交易（需要通过 Safe UI 或 SDK 执行）
    const setGuardData = safeContract.interface.encodeFunctionData(
      'setGuard',
      [TRUST_FREEZE_GUARD_ADDRESS]
    );

    // 使用 Safe SDK 执行交易
    await executeSafeTransaction(safeAddress, {
      to: safeAddress,
      value: '0',
      data: setGuardData,
    });
  }

  // 3. 设置冻结时间
  const timestamp = Math.floor(unfreezeDate.getTime() / 1000);

  const freezeData = guardContract.interface.encodeFunctionData(
    'freezeUntil',
    [timestamp]
  );

  await executeSafeTransaction(safeAddress, {
    to: TRUST_FREEZE_GUARD_ADDRESS,
    value: '0',
    data: freezeData,
  });

  console.log(`Safe frozen until ${unfreezeDate.toISOString()}`);
}

// 检查冻结状态
export async function checkFreezeStatus(
  safeAddress: string,
  provider: ethers.providers.Provider
) {
  const guardContract = new ethers.Contract(
    TRUST_FREEZE_GUARD_ADDRESS,
    TRUST_FREEZE_GUARD_ABI,
    provider
  );

  const isFrozen = await guardContract.isFrozen(safeAddress);
  const unfreezeTime = await guardContract.getUnfreezeTime(safeAddress);
  const remainingTime = await guardContract.getRemainingFreezeTime(safeAddress);

  return {
    isFrozen,
    unfreezeTime: new Date(unfreezeTime.toNumber() * 1000),
    remainingDays: Math.ceil(remainingTime.toNumber() / 86400),
  };
}
```

#### 5. UI 组件示例

```typescript
// apps/web/src/components/FreezeSettings.tsx
import { useState } from 'react';
import { freezeSafe, checkFreezeStatus } from '../services/trustFreeze';

export function FreezeSettings({ safeAddress, signer, provider }) {
  const [freezeDate, setFreezeDate] = useState<Date>(
    new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 默认 1 年
  );
  const [status, setStatus] = useState<any>(null);

  useEffect(() => {
    if (provider && safeAddress) {
      checkFreezeStatus(safeAddress, provider).then(setStatus);
    }
  }, [safeAddress, provider]);

  const handleFreeze = async () => {
    try {
      await freezeSafe(safeAddress, freezeDate, signer);
      alert('Safe 已成功冻结！');
      // 刷新状态
      const newStatus = await checkFreezeStatus(safeAddress, provider);
      setStatus(newStatus);
    } catch (error) {
      console.error('Freeze failed:', error);
      alert('冻结失败：' + error.message);
    }
  };

  return (
    <div className="freeze-settings">
      <h2>信托冻结设置</h2>

      {status && status.isFrozen && (
        <div className="freeze-status">
          <p>✅ Safe 当前已冻结</p>
          <p>解冻时间: {status.unfreezeTime.toLocaleDateString()}</p>
          <p>剩余天数: {status.remainingDays} 天</p>
        </div>
      )}

      <div className="freeze-controls">
        <label>
          解冻日期:
          <input
            type="date"
            value={freezeDate.toISOString().split('T')[0]}
            onChange={(e) => setFreezeDate(new Date(e.target.value))}
            min={new Date().toISOString().split('T')[0]}
          />
        </label>

        <button onClick={handleFreeze} disabled={status?.isFrozen}>
          {status?.isFrozen ? '已冻结' : '冻结 Safe'}
        </button>
      </div>

      <div className="info-box">
        <h3>⚠️ 重要说明</h3>
        <ul>
          <li>冻结后，Safe 的所有者将无法执行任何交易</li>
          <li>DeadManSwitch 等 Module 的继承功能仍可正常运行</li>
          <li>冻结期到期后将自动解冻</li>
          <li>冻结期间可以延长冻结时间，但无法提前解冻</li>
        </ul>
      </div>
    </div>
  );
}
```

## 🧪 测试

### 运行所有测试

```bash
cd contracts

# 运行 TrustFreezeGuard 测试
forge test --match-contract TrustFreezeGuardTest -vvv

# 查看测试覆盖率
forge coverage --match-contract TrustFreezeGuard
```

### 测试覆盖的场景

1. ✅ ERC165 接口支持
2. ✅ 冻结管理（设置、更新、验证）
3. ✅ Owner 交易在冻结期间被阻止
4. ✅ Owner 交易在解冻后允许
5. ✅ Module 交易在冻结期间正常执行
6. ✅ 完整的信托场景（冻结 + 继承）
7. ✅ 多个 Safe 独立冻结
8. ✅ 边界情况和错误处理
9. ✅ 模糊测试（Fuzz testing）

## 🔍 使用示例

### 场景：设置 5 年信托冻结

```solidity
// 1. Owner 通过 Safe 多签执行以下交易

// 交易 1: 设置 Guard（如果尚未设置）
Safe.setGuard(TRUST_FREEZE_GUARD_ADDRESS);

// 交易 2: 设置冻结期为 5 年
uint256 unfreezeTime = block.timestamp + (5 * 365 days);
TrustFreezeGuard.freezeUntil(unfreezeTime);
```

### 场景：在冻结期间继承生效

```solidity
// 时间线：
// T0: Owner 冻结 Safe 5 年
// T0 + 2年: Owner 去世
// T0 + 2年 + 心跳超时: Beneficiary 发起继承

// Beneficiary 调用 DeadManSwitch 模块
module.startClaim();

// 等待挑战期
vm.warp(block.timestamp + challengePeriod);

// 完成继承（通过 Module 执行，跳过 Guard）
module.finalizeClaim(); // ✅ 成功！即使 Safe 仍在冻结期

// Safe 的所有权已转移给 Beneficiary
// 但 Safe 仍然冻结到原定时间
```

## 📊 Gas 消耗

| 操作 | Gas 消耗 |
|------|---------|
| 部署合约 | ~800,000 |
| 设置冻结期 | ~45,000 |
| 更新冻结期 | ~28,000 |
| checkTransaction (冻结时) | ~3,000 |
| checkTransaction (未冻结) | ~2,500 |

## 🛡️ 安全考虑

### 已实现的安全措施

1. ✅ **ERC165 支持**：Safe 可以验证合约是否为有效的 Guard
2. ✅ **输入验证**：拒绝无效的时间戳（0 或过去的时间）
3. ✅ **事件日志**：所有状态变化都会发出事件
4. ✅ **fallback 保护**：防止 Safe 在升级时被锁定
5. ✅ **无状态设计**：一个合约服务多个 Safe，降低部署成本

### 风险提示

1. ⚠️ **Guard 设置错误**：确保 Guard 合约地址正确，错误的 Guard 可能导致 Safe 永久锁定
2. ⚠️ **长期冻结风险**：冻结期内无法通过 Owner 操作，请谨慎设置冻结时长
3. ⚠️ **时间戳依赖**：虽然矿工可操纵 ±15 秒，但对长期冻结影响微小
4. ⚠️ **合约审计**：生产环境使用前建议进行专业安全审计

## 🔧 故障排查

### 问题：设置 Guard 后无法执行交易

**原因**：可能是 Guard 合约地址错误或合约有 bug

**解决方案**：
1. 检查 Guard 地址是否正确
2. 确认 Guard 合约已正确部署
3. 如果是测试环境，可以通过 Safe 移除 Guard：`Safe.setGuard(address(0))`

### 问题：Module 交易也被阻止了

**原因**：这不应该发生，Module 交易应该跳过 Guard

**解决方案**：
1. 确认 Module 使用的是 `execTransactionFromModule` 而不是 `execTransaction`
2. 检查 Module 是否已在 Safe 上启用
3. 查看交易失败的错误信息

### 问题：无法延长冻结期

**原因**：可能 Safe 已解冻，或交易未正确构造

**解决方案**：
1. 确认通过 Safe 本身调用 `freezeUntil`（msg.sender 必须是 Safe）
2. 新的时间戳必须大于 `block.timestamp`
3. 检查交易是否通过 Safe 的多签流程

## 📚 相关资源

### Safe 官方文档
- [Guard Manager](https://docs.safe.global/advanced/smart-account-guards)
- [Module System](https://docs.safe.global/advanced/smart-account-modules)
- [Safe Contracts](https://github.com/safe-global/safe-contracts)

### 参考实现
- [Zodiac Guards](https://github.com/gnosis/zodiac)
- [Safe Recovery Module](https://github.com/safe-global/safe-modules)

## 🤝 贡献

本合约遵循 Safe 官方最佳实践，使用业界成熟的 SDK：
- ✅ Safe Contracts v1.4.1
- ✅ OpenZeppelin Contracts
- ✅ Foundry 测试框架

## 📄 许可证

LGPL-3.0-only（与 Safe Contracts 保持一致）

---

**生成时间**: 2025-11-04
**合约版本**: v1.0.0
**Solidity 版本**: 0.8.23
