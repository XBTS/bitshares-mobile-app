//
//  VCAssetOpReserve.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpReserve.h"
#import "VCSearchNetwork.h"
#import "ViewTipsInfoCell.h"

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecAmount,           //  数量
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kTailerTagAssetName = 1,
    kTailerTagSpace,
    kTailerTagBtnAll
};

@interface VCAssetOpReserve ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_asset;
    NSDictionary*               _full_account_data;
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    ViewTextFieldAmountCell*    _tf_amount;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbCommit;
}

@end

@implementation VCAssetOpReserve

-(void)dealloc
{
    _result_promise = nil;
    _nCurrBalance = nil;
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _curr_asset = curr_asset;
        _full_account_data = full_account_data;
        _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_curr_asset objectForKey:@"symbol"];
    if (not_enough) {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@(%@)",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol,
                           NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
        [_tf_amount drawUI_titleValue:value color:theme.tintColor];
    } else {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol];
        [_tf_amount drawUI_titleValue:value color:theme.textColorMain];
    }
}

- (NSString*)genTransferTipsMessage
{
    return @"【温馨提示】\n销毁会减少当前流通量。此操作不可逆，请谨慎操作。";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    //  TODO:4.0 lang
    
    //  UI - 数量输入框
    _tf_amount = [[ViewTextFieldAmountCell alloc] initWithTitle:NSLocalizedString(@"kOtcMcAssetTransferCellLabelAmount", @"数量")
                                                    placeholder:@"请输入销毁数量"
                                                         tailer:[_curr_asset objectForKey:@"symbol"]];
    _tf_amount.delegate = self;
    [self _drawUI_Balance:NO];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    _lbCommit = [self createCellLableButton:@"立即销毁"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount endInput];
}

#pragma mark- for UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[_curr_asset objectForKey:@"precision"] integerValue]];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecOpAsst) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecAmount:
            return 28.0f + 44.0f;
        case kVcSecTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAsset", @"资产");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.text = [_curr_asset objectForKey:@"symbol"];
            }
            return cell;
        }
            break;
        case kVcSecAmount:
            return _tf_amount;
            
        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecOpAsst:
                [self onSelectAssetClicked];
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSelectAssetClicked
{
    //  TODO:4.0 type
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetUIA callback:^(id asset_info) {
        if (asset_info){
            NSString* new_id = [asset_info objectForKey:@"id"];
            NSString* old_id = [_curr_asset objectForKey:@"id"];
            if (![new_id isEqualToString:old_id]) {
                _curr_asset = asset_info;
                //  切换资产后重新输入
                _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
                [_tf_amount clearInputTextValue];
                [_tf_amount drawUI_newTailer:[_curr_asset objectForKey:@"symbol"]];
                [self _drawUI_Balance:NO];
                [_mainTableView reloadData];
            }
        }
    }];
    //    vc.title = @"资产查询";//TODO:4.0 lang
    [self pushViewController:vc
                     vctitle:@"搜索资产"
                   backtitle:kVcDefaultBackTitleName];
}

- (void)onSubmitClicked
{
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:@"请输入要销毁的资产数量。"];
        return;
    }
    
    if ([_nCurrBalance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    id value = [NSString stringWithFormat:@"您确认销毁 %@ %@ 吗？\n\n※ 此操作不可逆，请谨慎操作。", n_amount, _curr_asset[@"symbol"]];
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:@"风险提示"
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAssetReserveCore:n_amount];
                }
            }];
        }
    }];
}

/*
 *  (private) 执行销毁操作
 */
- (void)_execAssetReserveCore:(NSDecimalNumber*)n_amount
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[_curr_asset[@"precision"] integerValue]]];
    id op = @{
        @"fee":@{@"amount":@0, @"asset_id":chainMgr.grapheneCoreAssetID},
        @"payer":op_account[@"id"],
        @"amount_to_reserve":@{@"amount":@([n_amount_pow unsignedLongLongValue]), @"asset_id":_curr_asset[@"id"]}
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_asset_reserve
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:op_account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] assetReserve:op] then:(^id(id data) {
            [self hideBlockView];
            [OrgUtils makeToast:@"销毁成功。"];
            //             [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVestingTipTxVestingBalanceWithdrawFullOK", @"待解冻金额 %@ 提取成功。"), balance_id]];
            //  [统计]
            //             [OrgUtils logEvents:@"txVestingBalanceWithdrawFullOK" params:@{@"account":uid}];
            //  刷新
            //             [self queryVestingBalance];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            //             [OrgUtils logEvents:@"txVestingBalanceWithdrawFailed" params:@{@"account":uid}];
            return nil;
        })];
    }];
}

#pragma mark- for ViewTextFieldAmountCellDelegate
- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue
{
    [self onAmountChanged:newValue];
}

- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onTailerClicked:(UIButton*)sender
{
    [_tf_amount setInputTextValue:[OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO]];
    [self onAmountChanged:nil];
}

/**
 *  (private) 划转数量发生变化。
 */
- (void)onAmountChanged:(NSDecimalNumber*)newValue
{
    if (!newValue) {
        newValue = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    }
    [self _drawUI_Balance:[_nCurrBalance compare:newValue] < 0];
}

@end
