from web3 import Web3
import json

# 连接到以太坊测试网络
web3 = Web3(Web3.HTTPProvider('http://127.0.0.1:8545'))

# 确保连接成功
assert web3.is_connected(), "Unable to connect to Ethereum network"

# 合约地址和 ABI（从部署步骤中获取）
contract_address = '0x139e546cc649643366b567d2e71b0ba91360df9d'
with open('B2Stake.json', 'r') as file:
    contract_abi = json.load(file)

checksum_address = web3.to_checksum_address(contract_address)

# 创建合约对象
contract = web3.eth.contract(address=checksum_address, abi=contract_abi)

# 获取默认账户
accounts = web3.eth.accounts
default_account = accounts[0]

# 获取合约状态
def get_pool(pid):
    return contract.functions.pools(pid).call()

def get_user(user_address, pid):
    return contract.functions.users(user_address, pid).call()

def calculate_reward(pid, user_address):
    return contract.functions.calculateReward(pid, user_address).call()

# 添加池子函数
def add_pool(pid, pool_address,  _poolWeight, _minDepositAmount, _unstakeLockedBlocks,_rewardPerBlock):
    try:
        # 构建交易
        transaction = contract.functions.addPool(pid, pool_address,  _poolWeight, _minDepositAmount,
                                                 _unstakeLockedBlocks, _rewardPerBlock).build_transaction({
            'from': web3.to_checksum_address(from_address),
            'gas': 2000000,
            'gasPrice': web3.to_wei('20', 'gwei'),
            'nonce': web3.eth.get_transaction_count(web3.to_checksum_address(from_address)),
        })

        # 签署交易
        signed_txn = web3.eth.account.sign_transaction(transaction, private_key=private_key)

        # 发送交易
        tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)

        # 返回交易哈希
        return tx_hash.hex()

    except Exception as e:
        print(f"An error occurred: {e}")
        return None

# 函数调用示例
def stake(pid, amount, private_key, from_address):
    try:
        # 构建交易
        transaction = contract.functions.stake(pid, amount).build_transaction({
            'from': web3.to_checksum_address(from_address),
            'gas': 2000000,
            'gasPrice': web3.to_wei('20', 'gwei'),
            'nonce': web3.eth.get_transaction_count(web3.to_checksum_address(from_address)),
        })

        # 签署交易
        signed_txn = web3.eth.account.sign_transaction(transaction, private_key=private_key)

        # 发送交易
        tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)

        # 返回交易哈希
        return tx_hash.hex()

    except Exception as e:
        print(f"An error occurred: {e}")

# 示例调用
if __name__ == "__main__":
    pid = 1  # Example pool ID
    amount = 200  # Amount to stake
    pool_address = '0xe066173cc99a1ccf4f9e92749ac3aa2d99c73775'
    reward_rate = 1000  # Example reward rate
    private_key = '0x8d94e5713960f00c23c34e03b9dafed0242845ddaa14692b9621f02919c8b3aa'
    from_address = '0xBB21C0246435D3631811384f2fE0008dDef68444'
    user_address = '0xfe0298bb6015b441aee9e795a5c9913a6836a2e2'
    user_address = web3.to_checksum_address(user_address)

    pool_address = web3.to_checksum_address(pool_address)
    # 调用 `addPool` 函数
    tx_hash = add_pool(pid, pool_address,  10,
            100,
            10,
            1)
    if tx_hash:
        print(f"Transaction hash: {tx_hash}")
    else:
        print("Failed to send transaction")

    # 获取池信息
    pool_info = get_pool(pid)
    print(f"Pool Info: {pool_info}")


