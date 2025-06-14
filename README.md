# 去中心化案件管理系統

這是一個基於智能合約的去中心化案件管理系統，允許參與者創建案件、進行投票和執行結果。

## 功能特點

### 案件管理
- 創建新案件（單個或批量）
- 設置案件賠償金額
- 支持多個案件同時進行
- 案件狀態追蹤（未激活、已激活、投票中、等待執行、已執行、已放棄）

### 投票系統
- 只有授權的投票者可以參與投票
- 支持平票情況下的預設勝者
- 投票時間限制
- 防止重複投票

### 代幣賠償
- 使用 ERC20 代幣進行賠償
- 支持手續費機制（押金和執行時的手續費）
- 安全的代幣轉移（使用 SafeERC20）

### 治理功能
- 合約管理員可以控制合約運行狀態
- 可調整手續費率
- 投票者管理

## 合約架構

### RealContract
主要合約，整合了案件管理和投票功能：

#### 狀態變量
- `voter`: 投票者合約地址
- `participantA` 和 `participantB`: 案件參與者
- `running`: 合約運行狀態
- `compensationToken`: 賠償代幣合約
- `feeRateForStakeCompensation`: 押金手續費率
- `feeRateForExecuteCase`: 執行手續費率

#### 修飾符
- `onlyParticipantOrGovernance`: 僅允許參與者或治理者調用
- `onlyParticipant`: 僅允許參與者調用
- `onlyRunning`: 僅允許在合約運行時調用

#### 主要功能
1. 案件管理
   - `addCase`: 添加單個案件
   - `addCases`: 批量添加案件
   - `stakeCompensation`: 繳納案件押金
   - `startCaseVoting`: 開始案件投票
   - `vote`: 進行投票
   - `executeCase`: 執行案件
   - `cancelCase`: 取消案件

2. 查詢功能
   - `getCaseResult`: 查詢案件結果

3. 治理功能
   - `setRunning`: 設置合約運行狀態

#### 事件
- `CaseAdded`: 新案件添加
- `CaseStaked`: 案件押金繳納
- `CaseVoted`: 投票記錄
- `CaseExecuted`: 案件執行
- `CaseCancelled`: 案件取消
- `CaseVotingStarted`: 開始投票
- `ContractStatusChanged`: 合約狀態變更

### CaseManager
案件管理合約：
- 案件狀態管理
- 投票結果計算
- 案件執行邏輯

### Voter
投票者管理合約：
- 投票者註冊和移除
- 投票者列表維護
- 高效的投票者管理（O(1) 添加和刪除）

## 技術特點

1. 安全性
   - 使用 OpenZeppelin 的 SafeERC20 進行安全的代幣轉移
   - 實現 ReentrancyGuard 防止重入攻擊
   - 嚴格的權限控制
   - 完整的狀態檢查

2. 效率
   - 優化的投票者管理（O(1) 操作）
   - 高效的案件狀態轉換
   - 最小化 gas 消耗

3. 可擴展性
   - 模塊化設計
   - 清晰的接口定義
   - 靈活的手續費機制

## 案件狀態

案件狀態包括：
- `Inactivated`: 未激活
- `Activated`: 已激活
- `Voting`: 投票中
- `WaitingForExecution`: 等待執行
- `Executed`: 已執行
- `Abandoned`: 已放棄

## 開發環境

- Solidity ^0.8.13
- OpenZeppelin Contracts
- Forge 測試框架

## 使用說明

1. 部署合約
   - 設置治理者地址
   - 設置投票者合約地址
   - 設置賠償代幣合約地址
   - 設置參與者地址
   - 設置手續費率

2. 案件流程
   - 參與者創建案件
   - 雙方繳納押金
   - 開始投票
   - 投票者進行投票
   - 執行案件結果

3. 手續費
   - 押金手續費：在繳納押金時收取
   - 執行手續費：在執行案件時收取

## 安全考慮

1. 重入保護
   - 使用 OpenZeppelin 的 ReentrancyGuard
   - 關鍵函數使用 nonReentrant 修飾符

2. 權限控制
   - 嚴格的參與者檢查
   - 治理者權限控制
   - 投票者權限控制

3. 代幣安全
   - 使用 SafeERC20 進行代幣轉移
   - 手續費計算和轉移的安全處理

## 授權

UNLICENSED
