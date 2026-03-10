import 'dart:convert';
import 'package:date_format/date_format.dart';
import 'package:fzwm_apl/model/currency_entity.dart';
import 'package:fzwm_apl/model/submit_entity.dart';
import 'package:fzwm_apl/utils/handler_order.dart';
import 'package:fzwm_apl/utils/refresh_widget.dart';
import 'package:fzwm_apl/utils/toast_util.dart';
import 'package:fzwm_apl/views/login/login_page.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:flutter_pickers/time_picker/model/date_mode.dart';
import 'package:flutter_pickers/time_picker/model/pduration.dart';
import 'package:flutter_pickers/time_picker/model/suffix.dart';
import 'dart:io';
import 'package:flutter_pickers/utils/check.dart';
import 'package:flutter/cupertino.dart';
import 'package:fzwm_apl/components/my_text.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qrscan/qrscan.dart' as scanner;

final String _fontFamily = Platform.isWindows ? "Roboto" : "";

class ConsignmentSettlementDetail extends StatefulWidget {
  var FBillNo;

  ConsignmentSettlementDetail({Key ?key, @required this.FBillNo}) : super(key: key);

  @override
  _ConsignmentSettlementDetailState createState() => _ConsignmentSettlementDetailState(FBillNo);
}

class _ConsignmentSettlementDetailState extends State<ConsignmentSettlementDetail> {
  var _remarkContent = new TextEditingController();
  var _FVBMYContent = new TextEditingController();
  GlobalKey<PartRefreshWidgetState> globalKey = GlobalKey();

  final _textNumber = TextEditingController();
  var checkItem;
  String FBillNo = '';
  String FSaleOrderNo = '';
  String FName = '';
  String cusName = '';
  String FNumber = '';
  String FDate = '';
  var customerName;
  var customerNumber;
  var typeName;
  var typeNumber;
  var show = false;
  var isSubmit = false;
  var isScanWork = false;
  var checkData;
  var fOrgID;
  var checkDataChild;
  var selectData = {
    DateMode.YMD: '',
  };
  var typeList = [];
  List<dynamic> typeListObj = [];
  var customerList = [];
  List<dynamic> customerListObj = [];
  var stockList = [];
  List<dynamic> stockListObj = [];
  List<dynamic> orderDate = [];
  List<dynamic> materialDate = [];
  final divider = Divider(height: 1, indent: 20);
  final rightIcon = Icon(Icons.keyboard_arrow_right);
  final scanIcon = Icon(Icons.filter_center_focus);
  static const scannerPlugin = const EventChannel('com.shinow.pda_scanner/plugin');
  StreamSubscription ?_subscription;
  var _code;
  var _FNumber;
  var fBillNo;
  var fBarCodeList;

  // 保管者下拉数据
  List<dynamic> keeperDisplayList = [];
  List<dynamic> keeperNumberList = [];
  var selectedKeeperDisplay;
  var selectedKeeperNumber;
  // 合同编号下拉数据
  List<dynamic> contractList = [];
  var selectedContract;

  _ConsignmentSettlementDetailState(FBillNo) {
    if (FBillNo != null) {
      this.fBillNo = FBillNo['value'];
      this.getOrderList();      // 有源单：加载具体订单明细
      isScanWork = true;
    } else {
      isScanWork = false;
      this.fBillNo = '';
      getCustomer();
      getStockList();
      getOrderListForSelection(); // 无源单：获取保管者/合同编号下拉选项
    }
  }

  @override
  void initState() {
    super.initState();
    DateTime dateTime = DateTime.now();
    var nowDate = "${dateTime.year}-${dateTime.month}-${dateTime.day}";
    selectData[DateMode.YMD] = nowDate;
    EasyLoading.dismiss();
    /// 开启监听
    if (_subscription == null) {
      _subscription = scannerPlugin
          .receiveBroadcastStream()
          .listen(_onEvent, onError: _onError);
    }
  }

  // 获取线路名称
  getTypeList() async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'BOS_ASSISTANTDATA_DETAIL';
    userMap['FieldKeys'] = 'FId,FDataValue,FNumber';
    userMap['FilterString'] = "FId ='5fd715f4883532' and FForbidStatus='A'";
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String res = await CurrencyEntity.polling(dataMap);
    typeListObj = jsonDecode(res);
    typeListObj.forEach((element) {
      typeList.add(element[1]);
    });
  }

  // 获取客户
  getCustomer() async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'BD_Customer';
    userMap['FieldKeys'] = 'FCUSTID,FName,FNumber';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String res = await CurrencyEntity.polling(dataMap);
    customerListObj = jsonDecode(res);
    customerListObj.forEach((element) {
      customerList.add(element[1]);
    });
  }

  // 获取仓库
  getStockList() async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'BD_STOCK';
    userMap['FieldKeys'] = 'FStockID,FName,FNumber,FIsOpenLocation';
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    if(fOrgID == null){
      this.fOrgID = deptData[1];
    }
    userMap['FilterString'] = "FForbidStatus = 'A' and FUseOrgId.FNumber ='"+fOrgID+"' and FStockProperty = 4";
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String res = await CurrencyEntity.polling(dataMap);
    stockListObj = jsonDecode(res);
    stockListObj.forEach((element) {
      stockList.add(element[1]);
    });
  }

  void getWorkShop() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      if (sharedPreferences.getString('FWorkShopName') != null) {
        FName = sharedPreferences.getString('FWorkShopName');
        FNumber = sharedPreferences.getString('FWorkShopNumber');
        isScanWork = true;
      } else {
        isScanWork = false;
      }
    });
  }

  @override
  void dispose() {
    this._textNumber.dispose();
    super.dispose();
    if (_subscription != null) {
      _subscription!.cancel();
    }
  }

  // 查询数据集合
  List hobby = [];
  List fNumber = [];

  // 有源单：获取订单明细，同时提取保管者/合同编号
  getOrderList() async {
    Map<String, dynamic> userMap = Map();
    print(fBillNo);
    userMap['FilterString'] = "fBillNo='$fBillNo' and FJoinUnSettleQty>0";
    userMap['FormId'] = 'STK_TransferDirect';
    userMap['OrderString'] = 'FMaterialId.FNumber ASC';
    userMap['FieldKeys'] =
    'FBillNo,FSaleOrgId.FNumber,FSaleOrgId.FName,FDate,FBillEntry_FEntryId,FMaterialId.FNumber,FMaterialId.FName,FMaterialId.FSpecification,FStockOrgId.FNumber,FStockOrgId.FName,FUnitId.FNumber,FUnitId.FName,FJoinUnSettleQty,FApproveDate,FQty,FID,FKeeperId.FNumber,FKeeperId.FName,FDestStockId.FName,FDestStockId.FNumber,FLot.FNumber,FDestStockId.FIsOpenLocation,FMaterialId.FIsBatchManage,FTaxPrice,FTaxRate,FBizType,FAllAmount,FDestStockLocId.FF100002.FNumber,FOrderNo,F_VZSF_Text,F_VZSF_UserId,F_VZSF_YSDH';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    orderDate = [];
    orderDate = jsonDecode(order);
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);

    // 提取保管者和合同编号下拉数据
    keeperDisplayList.clear();
    keeperNumberList.clear();
    contractList.clear();
    for (var row in orderDate) {
      String keeperName = row[17] ?? '';
      String keeperNumber = row[16] ?? '';
      String contract = row[29] ?? '';
      if (!keeperNumberList.contains(keeperNumber) && keeperNumber.isNotEmpty) {
        keeperNumberList.add(keeperNumber);
        keeperDisplayList.add('$keeperName ($keeperNumber)');
      }
      if (!contractList.contains(contract) && contract.isNotEmpty) {
        contractList.add(contract);
      }
    }
    if (keeperDisplayList.isNotEmpty) {
      selectedKeeperDisplay = keeperDisplayList.first;
      selectedKeeperNumber = keeperNumberList.first;
    }
    if (contractList.isNotEmpty) {
      selectedContract = contractList.first;
    }

    if (orderDate.length > 0) {
      this.FBillNo = orderDate[0][0];
      this.cusName = orderDate[0][17];
      this.fOrgID = orderDate[0][8];
      hobby = [];
      orderDate.forEach((value) {
        fNumber.add(value[5]);
        List arr = [];
        arr.add({
          "title": "物料名称",
          "name": "FMaterial",
          "isHide": false,
          "value": {"label": value[6] + "- (" + value[5] + ")", "value": value[5],"barcode": [],"kingDeeCode": [],"scanCode": []}
        });
        arr.add({
          "title": "规格型号",
          "name": "FMaterialIdFSpecification",
          "isHide": false,
          "value": {"label": value[7], "value": value[7]}
        });
        arr.add({
          "title": "单位名称",
          "name": "FUnitId",
          "isHide": false,
          "value": {"label": value[11], "value": value[10]}
        });
        arr.add({
          "title": "结算数量",
          "name": "FJoinRetQty",
          "isHide": false,
          "value": {"label": "0", "value": "0"}
        });
        arr.add({
          "title": "仓库",
          "name": "FStockID",
          "isHide": false,
          "value": {"label": value[18], "value": value[19]}
        });
        arr.add({
          "title": "批号",
          "name": "FLot",
          "isHide": value[22] != true,
          "value": {"label": "", "value": ""}
        });
        arr.add({
          "title": "仓位",
          "name": "FStockLocID",
          "isHide": false,
          "value": {"label": value[27]==null|| value[27] ==''?'':value[27], "value": value[27]==null|| value[27] ==''?'':value[27],"hide": value[21]}
        });
        arr.add({
          "title": "操作",
          "name": "",
          "isHide": false,
          "value": {"label": "", "value": ""}
        });
        arr.add({
          "title": "库存单位",
          "name": "",
          "isHide": true,
          "value": {"label": value[11], "value": value[10]}
        });
        arr.add({
          "title": "调拨数量",
          "name": "",
          "isHide": false,
          "value": {"label": value[12], "value": value[12]}
        });
        arr.add({
          "title": "最后扫描数量",
          "name": "FLastQty",
          "isHide": false,
          "value": {
            "label": "0",
            "value": "0"
          }
        });
        hobby.add(arr);
      });
      setState(() {
        EasyLoading.dismiss();
        this._getHobby();
      });
    } else {
      setState(() {
        EasyLoading.dismiss();
        this._getHobby();
      });
      ToastUtil.showInfo('无数据');
    }
    getStockList();
  }

  // 无源单：获取保管者/合同编号下拉选项（从历史订单中提取）
  getOrderListForSelection() async {
    Map<String, dynamic> userMap = Map();
    userMap['FilterString'] = "FJoinUnSettleQty>0"; // 未完全结算的调拨单
    userMap['FormId'] = 'STK_TransferDirect';
    userMap['OrderString'] = 'FDate DESC';
    userMap['FieldKeys'] = 'FKeeperId.FNumber,FKeeperId.FName,F_VZSF_Text';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    var orderList = jsonDecode(order);

    // 去重填充
    Set<String> keeperNumberSet = Set();
    Set<String> contractSet = Set();
    List<String> tempKeeperDisplay = [];
    List<String> tempKeeperNumber = [];
    List<String> tempContract = [];

    for (var row in orderList) {
      String keeperNumber = row[0] ?? '';
      String keeperName = row[1] ?? '';
      String contract = row[2] ?? '';

      if (keeperNumber.isNotEmpty && !keeperNumberSet.contains(keeperNumber)) {
        keeperNumberSet.add(keeperNumber);
        tempKeeperNumber.add(keeperNumber);
        tempKeeperDisplay.add('$keeperName ($keeperNumber)');
      }
      if (contract.isNotEmpty && !contractSet.contains(contract)) {
        contractSet.add(contract);
        tempContract.add(contract);
      }
    }

    setState(() {
      keeperDisplayList = tempKeeperDisplay;
      keeperNumberList = tempKeeperNumber;
      contractList = tempContract;
      if (keeperDisplayList.isNotEmpty) {
        selectedKeeperDisplay = keeperDisplayList.first;
        selectedKeeperNumber = keeperNumberList.first;
      }
      if (contractList.isNotEmpty) {
        selectedContract = contractList.first;
      }
    });
  }

  void _onEvent(event) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var deptData = sharedPreferences.getString('menuList');
    var menuList = new Map<dynamic, dynamic>.from(jsonDecode(deptData));
    fBarCodeList = menuList['FBarCodeList'];
    if(event == ""){
      return;
    }
    if(checkItem == "position"){
      setState(() {
        this._FNumber = event;
        this._textNumber.text = event;
      });
    }else{
      if (fBarCodeList == 1) {
        Map<String, dynamic> barcodeMap = Map();
        barcodeMap['FilterString'] = "FBarCodeEn='" + event + "'";
        barcodeMap['FormId'] = 'QDEP_Cust_BarCodeList';
        barcodeMap['FieldKeys'] =
        'FID,FInQtyTotal,FOutQtyTotal,FEntity_FEntryId,FRemainQty,FBarCodeQty,FStockID.FName,FStockID.FNumber,FMATERIALID.FNUMBER,FOwnerID.FNumber,FBarCode,FSN,FStockLocNumberH,FStockID.FIsOpenLocation';
        Map<String, dynamic> dataMap = Map();
        dataMap['data'] = barcodeMap;
        String order = await CurrencyEntity.polling(dataMap);
        var barcodeData = jsonDecode(order);
        if (barcodeData.length > 0) {
          var msg = "";
          var orderIndex = 0;
          for (var value in orderDate) {
            if(value[5] == barcodeData[0][8]){
              msg = "";
              if(fNumber.lastIndexOf(barcodeData[0][8])  == orderIndex){
                break;
              }
            }else{
              msg = '条码不在单据物料中';
            }
            orderIndex++;
          };
          if(msg ==  ""){
            _code = event;
            this.getMaterialList(barcodeData, barcodeData[0][10], barcodeData[0][11], barcodeData[0][12], barcodeData[0][13]);
            print("ChannelPage: $event");
          }else{
            ToastUtil.showInfo(msg);
          }
        } else {
          ToastUtil.showInfo('条码不在条码清单中');
        }
      } else {
        _code = event;
        this.getMaterialList("", _code,"", "", false);
        print("ChannelPage: $event");
      }
    }

    print("ChannelPage: $event");
  }

  void _onError(Object error) {
    setState(() {
      _code = "扫描异常";
    });
  }

  getMaterialList(barcodeData, code, fsn, fLoc,fIsOpenLocation) async {
    Map<String, dynamic> userMap = Map();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    var scanCode = code.split(";");
    userMap['FilterString'] = "FNumber='"+barcodeData[0][8]+"' and FForbidStatus = 'A' and FUseOrgId.FNumber = '"+deptData[1]+"'";
    userMap['FormId'] = 'BD_MATERIAL';
    userMap['FieldKeys'] =
    'FMATERIALID,FName,FNumber,FSpecification,FBaseUnitId.FName,FBaseUnitId.FNumber,FIsBatchManage';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    materialDate = [];
    materialDate = jsonDecode(order);
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    if (materialDate.length > 0) {
      var number = 0;
      var barCodeScan;
      if(fBarCodeList == 1){
        barCodeScan = barcodeData[0];
        barCodeScan[4] = barCodeScan[4].toString();
      }else{
        barCodeScan = scanCode;
      }
      var errorTitle = "";
      var barcodeNum = scanCode[3];
      for (var element in hobby) {
        var residue = 0.0;
        //判断是否启用批号
        if(element[5]['isHide']){//不启用
          if(element[0]['value']['value'] == scanCode[0]){
            if(element[0]['value']['barcode'].indexOf(code) == -1){
              if(scanCode.length>4) {
                element[0]['value']['barcode'].add(code);
              }
              if(scanCode[5] == "N" ){
                if(element[0]['value']['scanCode'].indexOf(code) == -1){
                  if(fIsOpenLocation){
                    element[6]['value']['hide'] = fIsOpenLocation;
                    if (element[6]['value']['value'] == "") {
                      element[6]['value']['label'] = fLoc == null? "":fLoc;
                      element[6]['value']['value'] =fLoc == null? "":fLoc;
                    }
                  }
                  //判断是否启用仓位
                  if (element[6]['value']['hide']) {
                    if (element[6]['value']['label'] == fLoc) {
                      errorTitle = "";
                    } else {
                      errorTitle = "仓位不一致";
                      continue;
                    }
                  }
                  element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                  element[3]['value']['value']=element[3]['value']['label'];
                  var item = barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                }
                break;
              }
              //判断扫描数量是否大于单据数量
              if(double.parse(element[3]['value']['label']) >= element[9]['value']['label']) {
                continue;
              }else {
                //判断条码数量
                if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) > 0 && double.parse(barcodeNum)>0){
                  //判断二维码数量是否大于单据数量
                  if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) >= element[9]['value']['label']){
                    //判断条码是否重复
                    if(element[0]['value']['scanCode'].indexOf(code) == -1){
                      if(fIsOpenLocation){
                        element[6]['value']['hide'] = fIsOpenLocation;
                        if (element[6]['value']['value'] == "") {
                          element[6]['value']['label'] = fLoc == null? "":fLoc;
                          element[6]['value']['value'] =fLoc == null? "":fLoc;
                        }
                      }
                      //判断是否启用仓位
                      if (element[6]['value']['hide']) {
                        if (element[6]['value']['label'] == fLoc) {
                          errorTitle = "";
                        } else {
                          errorTitle = "仓位不一致";
                          continue;
                        }
                      }
                      var item = barCodeScan[0].toString()+"-"+(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString() + "-" + fsn;
                      element[10]['value']['label'] =(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                      element[10]['value']['value'] = (element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                      barcodeNum = (double.parse(barcodeNum) - (element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      residue = element[9]['value']['label'] - double.parse(element[3]['value']['label']);
                      element[0]['value']['kingDeeCode'].add(item);
                      element[0]['value']['scanCode'].add(code);
                      print(1);
                      print(element[0]['value']['kingDeeCode']);
                    }
                  }else{
                    //数量不超出
                    //判断条码是否重复
                    if(element[0]['value']['scanCode'].indexOf(code) == -1){
                      if(fIsOpenLocation){
                        element[6]['value']['hide'] = fIsOpenLocation;
                        if (element[6]['value']['value'] == "") {
                          element[6]['value']['label'] = fLoc == null? "":fLoc;
                          element[6]['value']['value'] =fLoc == null? "":fLoc;
                        }
                      }
                      //判断是否启用仓位
                      if (element[6]['value']['hide']) {
                        if (element[6]['value']['label'] == fLoc) {
                          errorTitle = "";
                        } else {
                          errorTitle = "仓位不一致";
                          continue;
                        }
                      }
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      var item = barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                      element[10]['value']['label'] =barcodeNum.toString();
                      element[10]['value']['value'] = barcodeNum.toString();
                      element[0]['value']['kingDeeCode'].add(item);
                      element[0]['value']['scanCode'].add(code);
                      barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                      print(2);
                      print(element[0]['value']['kingDeeCode']);
                    }
                  }
                }
              }

            }else{
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        }else{
          //启用批号
          if(element[0]['value']['value'] == scanCode[0]){
            if(element[0]['value']['barcode'].indexOf(code) == -1){
              if(scanCode.length>4) {
                element[0]['value']['barcode'].add(code);
              }
              if(scanCode[5] == "N" ){
                if(element[0]['value']['scanCode'].indexOf(code) == -1){
                  if(fIsOpenLocation){
                    element[6]['value']['hide'] = fIsOpenLocation;
                    if (element[6]['value']['value'] == "") {
                      element[6]['value']['label'] = fLoc == null? "":fLoc;
                      element[6]['value']['value'] =fLoc == null? "":fLoc;
                    }
                  }
                  //判断是否启用仓位
                  if (element[6]['value']['hide']) {
                    if (element[6]['value']['label'] == fLoc) {
                      errorTitle = "";
                    } else {
                      errorTitle = "仓位不一致";
                      continue;
                    }
                  }
                  if(element[5]['value']['value'] == "") {
                    element[5]['value']['label'] = scanCode[1];
                    element[5]['value']['value'] = scanCode[1];
                  }
                  element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                  element[3]['value']['value']=element[3]['value']['label'];
                  var item = barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                }
                break;
              }
              if(element[5]['value']['value'] == scanCode[1]){

                //判断扫描数量是否大于单据数量
                if(double.parse(element[3]['value']['label']) >= element[9]['value']['label']) {
                  continue;
                }else {
                  //判断条码数量
                  if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) > 0 && double.parse(barcodeNum)>0){
                    //判断二维码数量是否大于单据数量
                    if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) >= element[9]['value']['label']){
                      //判断条码是否重复
                      if(element[0]['value']['scanCode'].indexOf(code) == -1){
                        if(fIsOpenLocation){
                          element[6]['value']['hide'] = fIsOpenLocation;
                          if (element[6]['value']['value'] == "") {
                            element[6]['value']['label'] = fLoc == null? "":fLoc;
                            element[6]['value']['value'] =fLoc == null? "":fLoc;
                          }
                        }
                        //判断是否启用仓位
                        if (element[6]['value']['hide']) {
                          if (element[6]['value']['label'] == fLoc) {
                            errorTitle = "";
                          } else {
                            errorTitle = "仓位不一致";
                            continue;
                          }
                        }
                        var item = barCodeScan[0].toString()+"-"+(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString() + "-" + fsn;
                        element[10]['value']['label'] =(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                        element[10]['value']['value'] = (element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                        barcodeNum = (double.parse(barcodeNum) - (element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        residue = element[9]['value']['label'] - double.parse(element[3]['value']['label']);
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                        print(1);
                        print(element[0]['value']['kingDeeCode']);
                      }
                    }else{
                      //数量不超出
                      //判断条码是否重复
                      if(element[0]['value']['scanCode'].indexOf(code) == -1){
                        if(fIsOpenLocation){
                          element[6]['value']['hide'] = fIsOpenLocation;
                          if (element[6]['value']['value'] == "") {
                            element[6]['value']['label'] = fLoc == null? "":fLoc;
                            element[6]['value']['value'] =fLoc == null? "":fLoc;
                          }
                        }
                        //判断是否启用仓位
                        if (element[6]['value']['hide']) {
                          if (element[6]['value']['label'] == fLoc) {
                            errorTitle = "";
                          } else {
                            errorTitle = "仓位不一致";
                            continue;
                          }
                        }
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        var item = barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                        element[10]['value']['label'] =barcodeNum.toString();
                        element[10]['value']['value'] = barcodeNum.toString();
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                        barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                        print(2);
                        print(element[0]['value']['kingDeeCode']);
                      }
                    }
                  }
                }
              }else{
                print(element[5]['value']['value'] == "");
                if(element[5]['value']['value'] == ""){

                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                  print(element[9]['value']['label']);
                  print(double.parse(element[3]['value']['label']));
                  print(double.parse(element[3]['value']['label']) >= element[9]['value']['label']);
                  //判断扫描数量是否大于单据数量
                  if(double.parse(element[3]['value']['label']) >= element[9]['value']['label']) {
                    continue;
                  }else {
                    //判断条码数量
                    if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) > 0 && double.parse(barcodeNum)>0){
                      //判断二维码数量是否大于单据数量
                      if((double.parse(element[3]['value']['label'])+double.parse(barcodeNum)) >= element[9]['value']['label']){
                        //判断条码是否重复
                        if(element[0]['value']['scanCode'].indexOf(code) == -1){
                          if(fIsOpenLocation){
                            element[6]['value']['hide'] = fIsOpenLocation;
                            if (element[6]['value']['value'] == "") {
                              element[6]['value']['label'] = fLoc == null? "":fLoc;
                              element[6]['value']['value'] =fLoc == null? "":fLoc;
                            }
                          }
                          //判断是否启用仓位
                          if (element[6]['value']['hide']) {
                            if (element[6]['value']['label'] == fLoc) {
                              errorTitle = "";
                            } else {
                              errorTitle = "仓位不一致";
                              continue;
                            }
                          }
                          var item = barCodeScan[0].toString()+"-"+(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString() + "-" + fsn;
                          element[10]['value']['label'] =(element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                          element[10]['value']['value'] = (element[9]['value']['label'] - double.parse(element[3]['value']['label'])).toString();
                          barcodeNum = (double.parse(barcodeNum) - (element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                          element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['label'] - double.parse(element[3]['value']['label']))).toString();
                          element[3]['value']['value']=element[3]['value']['label'];
                          residue = element[9]['value']['label'] - double.parse(element[3]['value']['label']);
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                          print(1);
                          print(element[0]['value']['kingDeeCode']);
                        }
                      }else{
                        //数量不超出
                        //判断条码是否重复
                        if(element[0]['value']['scanCode'].indexOf(code) == -1){
                          if(fIsOpenLocation){
                            element[6]['value']['hide'] = fIsOpenLocation;
                            if (element[6]['value']['value'] == "") {
                              element[6]['value']['label'] = fLoc == null? "":fLoc;
                              element[6]['value']['value'] =fLoc == null? "":fLoc;
                            }
                          }
                          //判断是否启用仓位
                          if (element[6]['value']['hide']) {
                            if (element[6]['value']['label'] == fLoc) {
                              errorTitle = "";
                            } else {
                              errorTitle = "仓位不一致";
                              continue;
                            }
                          }
                          element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                          element[3]['value']['value']=element[3]['value']['label'];
                          var item = barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                          element[10]['value']['label'] =barcodeNum.toString();
                          element[10]['value']['value'] = barcodeNum.toString();
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                          barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                          print(2);
                          print(element[0]['value']['kingDeeCode']);
                        }
                      }
                    }
                  }
                }
              }
            }else{
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        }
      }
      if(number ==0 && this.fBillNo =="") {
        materialDate.forEach((value) {
          List arr = [];
          arr.add({
            "title": "物料名称",
            "name": "FMaterial",
            "isHide": false,
            "value": {"label": value[1] + "- (" + value[2] + ")", "value": value[2],"barcode": [code],"kingDeeCode": [barCodeScan[0].toString()+"-"+scanCode[3]+"-"+fsn],"scanCode": [barCodeScan[0].toString()+"-"+scanCode[3]]}
          });
          arr.add({
            "title": "规格型号",
            "isHide": false,
            "name": "FMaterialIdFSpecification",
            "value": {"label": value[3], "value": value[3]}
          });
          arr.add({
            "title": "单位名称",
            "name": "FUnitId",
            "isHide": false,
            "value": {"label": value[4], "value": value[5]}
          });
          arr.add({
            "title": "结算数量",
            "name": "FRealQty",
            "isHide": false,
            "value": {"label": scanCode[3].toString(), "value": scanCode[3].toString()}
          });
          arr.add({
            "title": "仓库",
            "name": "FStockID",
            "isHide": false,
            "value": {"label": barcodeData[0][6], "value": barcodeData[0][7]}
          });
          arr.add({
            "title": "批号",
            "name": "FLot",
            "isHide": value[6] != true,
            "value": {"label": value[6]?(scanCode.length>1?scanCode[1]:''):'', "value": value[6]?(scanCode.length>1?scanCode[1]:''):''}
          });
          arr.add({
            "title": "仓位",
            "name": "FStockLocID",
            "isHide": false,
            "value": {"label": fLoc, "value": fLoc, "hide": fIsOpenLocation}
          });
          arr.add({
            "title": "操作",
            "name": "",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "库存单位",
            "name": "",
            "isHide": true,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "调拨数量",
            "name": "",
            "isHide": false,
            "value": {"label": scanCode[3].toString(), "value": scanCode[3].toString()}
          });
          arr.add({
            "title": "最后扫描数量",
            "name": "FLastQty",
            "isHide": false,
            "value": {
              "label": scanCode[3].toString(),
              "value": scanCode[3].toString()
            }
          });
          hobby.add(arr);
        });
      }
      setState(() {
        EasyLoading.dismiss();
        this._getHobby();
      });
    } else {
      setState(() {
        EasyLoading.dismiss();
        this._getHobby();
      });
      ToastUtil.showInfo('无数据');
    }
  }

  // 新增：查询匹配的调拨单分录
  Future<List<dynamic>?> _fetchMatchingEntry(String contractNo, String keeperNumber, String materialNumber, double qty) async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'STK_TransferDirect';
    userMap['FieldKeys'] =
    'FBillNo,FSaleOrgId.FNumber,FSaleOrgId.FName,FDate,FBillEntry_FEntryId,FMaterialId.FNumber,FMaterialId.FName,FMaterialId.FSpecification,FStockOrgId.FNumber,FStockOrgId.FName,FUnitId.FNumber,FUnitId.FName,FJoinUnSettleQty,FApproveDate,FQty,FID,FKeeperId.FNumber,FKeeperId.FName,FDestStockId.FName,FDestStockId.FNumber,FLot.FNumber,FDestStockId.FIsOpenLocation,FMaterialId.FIsBatchManage,FTaxPrice,FTaxRate,FBizType,FAllAmount,FDestStockLocId.FF100002.FNumber,FOrderNo,F_VZSF_Text,F_VZSF_UserId,F_VZSF_YSDH';
    userMap['FilterString'] = "F_VZSF_Text = '$contractNo' AND FKeeperId.FNumber = '$keeperNumber' AND FMaterialId.FNumber = '$materialNumber' AND FJoinUnSettleQty >= $qty AND FJoinUnSettleQty > 0";
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String res = await CurrencyEntity.polling(dataMap);
    var list = jsonDecode(res);
    return list.isNotEmpty ? list.first : null;
  }

  Widget _item(title, var data, selectData, hobby, {String ?label,var stock}) {
    if (selectData == null) {
      selectData = "";
    }
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: ListTile(
            title: Text(title),
            onTap: () => data.length>0?_onClickItem(data, selectData, hobby, label: label,stock: stock):{ToastUtil.showInfo('无数据')},
            trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Container(
                constraints: BoxConstraints(maxWidth: 150),
                child: Text(
                  selectData.toString()=="" ? '暂无':selectData.toString(),
                  style: TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              rightIcon
            ]),
          ),
        ),
        divider,
      ],
    );
  }

  Widget _dateItem(title, model) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: ListTile(
            title: Text(title),
            onTap: () {
              _onDateClickItem(model);
            },
            trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              MyText(
                  (PicketUtil.strEmpty(selectData[model])
                      ? '暂无'
                      : selectData[model])!,
                  color: Colors.grey,
                  rightpadding: 18),
              rightIcon
            ]),
          ),
        ),
        divider,
      ],
    );
  }

  void _onDateClickItem(model) {
    Pickers.showDatePicker(
      context,
      mode: model,
      suffix: Suffix.normal(),
      minDate: PDuration(year: 2020, month: 2, day: 10),
      maxDate: PDuration(second: 22),
      selectDate: (FDate == '' || FDate == null
          ? PDuration(year: 2021, month: 2, day: 10)
          : PDuration.parse(DateTime.parse(FDate))),
      onConfirm: (p) {
        print('longer >>> 返回数据：$p');
        setState(() {
          switch (model) {
            case DateMode.YMD:
              Map<String, dynamic> userMap = Map();
              selectData[model] = formatDate(DateFormat('yyyy-MM-dd').parse('${p.year}-${p.month}-${p.day}'), [yyyy, "-", mm, "-", dd,]);
              FDate = formatDate(DateFormat('yyyy-MM-dd').parse('${p.year}-${p.month}-${p.day}'), [yyyy, "-", mm, "-", dd,]);
              break;
          }
        });
      },
    );
  }

  // 新增：可搜索的下拉选择弹窗
  Future<void> _showSearchablePicker({
    required List<String> items,
    required String currentValue,
    required Function(String) onSelected,
  }) async {
    TextEditingController searchController = TextEditingController();
    List<String> filteredItems = List.from(items);
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('请选择'),
              content: Container(
                width: double.maxFinite,
                height: 400, // 固定高度
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '搜索...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredItems = items
                              .where((item) => item.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => Divider(height: 1, indent: 20), // 分割线
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(filteredItems[index]),
                            onTap: () {
                              onSelected(filteredItems[index]);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onClickItem(var data, var selectData, hobby, {String ?label,var stock}) {
    if (hobby == 'keeper' || hobby == 'contract') {
      // 保管者和合同使用可搜索弹窗
      _showSearchablePicker(
        items: data,
        currentValue: selectData ?? '',
        onSelected: (selected) {
          setState(() {
            if (hobby == 'keeper') {
              selectedKeeperDisplay = selected;
              int index = keeperDisplayList.indexOf(selected);
              if (index != -1) {
                selectedKeeperNumber = keeperNumberList[index];
              }
            } else if (hobby == 'contract') {
              selectedContract = selected;
            }
          });
        },
      );
    } else {
      // 其他原有下拉保持原样
      Pickers.showSinglePicker(
        context,
        data: data,
        selectData: selectData,
        pickerStyle: DefaultPickerStyle(),
        suffix: label,
        onConfirm: (p) {
          print('longer >>> 返回数据：$p');
          setState(() {
            if(hobby  == 'customer'){
              customerName = p;
              var elementIndex = 0;
              data.forEach((element) {
                if (element == p) {
                  customerNumber = customerListObj[elementIndex][2];
                }
                elementIndex++;
              });
            } else {
              setState(() {
                hobby['value']['label'] = p;
              });
              var elementIndex = 0;
              data.forEach((element) {
                if (element == p) {
                  hobby['value']['value'] = stockListObj[elementIndex][2];
                  stock[6]['value']['hide'] = stockListObj[elementIndex][3];
                  stock[6]['value']['value'] = "";
                  stock[6]['value']['label'] = "";
                }
                elementIndex++;
              });
            }
          });
        },
      );
    }
  }

  List<Widget> _getHobby() {
    List<Widget> tempList = [];
    for (int i = 0; i < this.hobby.length; i++) {
      List<Widget> comList = [];
      for (int j = 0; j < this.hobby[i].length; j++) {
        if (!this.hobby[i][j]['isHide']) {
          if (j == 4) {
            comList.add(
              _item('仓库:', stockList, this.hobby[i][j]['value']['label'],
                  this.hobby[i][j],stock:this.hobby[i]),
            );
          }else if(j == 6){
            comList.add(
              Visibility(
                maintainSize: false,
                maintainState: false,
                maintainAnimation: false,
                visible: this.hobby[i][j]["value"]["hide"],
                child: Column(children: [
                  Container(
                    color: Colors.white,
                    child: ListTile(
                        title: Text(this.hobby[i][j]["title"] +
                            '：' +
                            this.hobby[i][j]["value"]["label"].toString()),
                        trailing:
                        Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          IconButton(
                            icon: new Icon(Icons.filter_center_focus),
                            tooltip: '点击扫描',
                            onPressed: () {
                              this._textNumber.text =
                                  this.hobby[i][j]["value"]["label"].toString();
                              this._FNumber =
                                  this.hobby[i][j]["value"]["label"].toString();
                              checkItem = 'position';
                              this.show = false;
                              checkData = i;
                              checkDataChild = j;
                              scanDialog();
                              print(this.hobby[i][j]["value"]["label"]);
                              if (this.hobby[i][j]["value"]["label"] != 0) {
                                this._textNumber.value = _textNumber.value.copyWith(
                                  text:
                                  this.hobby[i][j]["value"]["label"].toString(),
                                );
                              }
                            },
                          ),
                        ])),
                  ),
                  divider,
                ]),
              ),
            );
          } else if (j == 7) {
            comList.add(
              Column(children: [
                Container(
                  color: Colors.white,
                  child: ListTile(
                      title: Text(this.hobby[i][j]["title"] +
                          '：' +
                          this.hobby[i][j]["value"]["label"].toString()),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            new FlatButton(
                              color: Colors.red,
                              textColor: Colors.white,
                              child: new Text('删除'),
                              onPressed: () {
                                this.hobby.removeAt(i);
                                setState(() {});
                              },
                            )
                          ])),
                ),
                divider,
              ]),
            );
          } else {
            comList.add(
              Column(children: [
                Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(this.hobby[i][j]["title"] +
                        '：' +
                        this.hobby[i][j]["value"]["label"].toString()),
                    trailing:
                    Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    ]),
                  ),
                ),
                divider,
              ]),
            );
          }
        }
      }
      tempList.add(
        SizedBox(height: 10),
      );
      tempList.add(
        Column(
          children: comList,
        ),
      );
    }
    return tempList;
  }

  //调出弹窗 扫码
  void scanDialog() {
    showDialog<Widget>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              alignment: Alignment.center,
              color: Colors.white,
              child: Column(
                children: <Widget>[
                  Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Card(
                          child: Column(children: <Widget>[
                            TextField(
                              style: TextStyle(color: Colors.black87),
                              keyboardType: TextInputType.number,
                              controller: this._textNumber,
                              decoration: InputDecoration(hintText: "输入"),
                              onChanged: (value) {
                                setState(() {
                                  this._FNumber = value;
                                });
                              },
                            ),
                          ]))),
                  Padding(
                    padding: EdgeInsets.only(top: 15, bottom: 8),
                    child: FlatButton(
                        color: Colors.grey[100],
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            this.hobby[checkData][checkDataChild]["value"]
                            ["label"] = _FNumber;
                            this.hobby[checkData][checkDataChild]['value']
                            ["value"] = _FNumber;
                            checkItem = '';
                          });
                        },
                        child: Text(
                          '确定',
                        )),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    ).then((val) {
      print(val);
    });
  }

  // 保存方法（重构后）
  saveOrder() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];

    if (this.hobby.isEmpty) {
      ToastUtil.showInfo('无提交数据');
      return;
    }

    String contractNo = selectedContract ?? '';
    String keeperNo = selectedKeeperNumber ?? '';

    // 1. 按物料分组计算总数量
    Map<String, Map<String, dynamic>> materialGroup = {}; // key: 物料编码, value: {qty: 总数量, rows: [索引]}
    for (int i = 0; i < hobby.length; i++) {
      var element = hobby[i];
      double qty = double.tryParse(element[3]['value']['value'] ?? '0') ?? 0;
      if (qty == 0) continue;

      String materialNo = element[0]['value']['value'];
      if (!materialGroup.containsKey(materialNo)) {
        materialGroup[materialNo] = {'qty': 0.0, 'rows': []};
      }
      materialGroup[materialNo]!['qty'] = materialGroup[materialNo]!['qty'] + qty;
      materialGroup[materialNo]!['rows'].add(i);
    }

    // 2. 对每组进行校验，并分配分录信息
    List<List<dynamic>?> matchingEntries = List.filled(hobby.length, null);
    for (var entry in materialGroup.entries) {
      String materialNo = entry.key;
      double totalQty = entry.value['qty'];
      List<dynamic> rowIndices = entry.value['rows'];
      var fetchedEntry = await _fetchMatchingEntry(contractNo, keeperNo, materialNo, totalQty);
      if (fetchedEntry == null) {
        String materialLabel = hobby[rowIndices.first][0]['value']['label'] ?? materialNo;
        ToastUtil.showInfo('物料 $materialLabel 总数量 $totalQty 未找到匹配的调拨单分录或可结算数量不足');
        setState(() => isSubmit = false);
        return;
      }
      // 为该组所有行分配相同的分录信息
      for (int idx in rowIndices) {
        matchingEntries[idx] = fetchedEntry;
      }
    }

    // 全部校验通过，开始构建保存数据
    setState(() => isSubmit = true);

    Map<String, dynamic> dataMap = Map();
    dataMap['formid'] = 'SAL_ConsignmentSettle';
    Map<String, dynamic> orderMap = Map();
    orderMap['NeedUpDataFields'] = ['FConsigSetEntity', 'FSerialSubEntity', 'FSerialNo'];
    orderMap['NeedReturnFields'] = ['FConsigSetEntity', 'FSerialSubEntity', 'FSerialNo'];
    orderMap['IsDeleteEntry'] = true;

    Map<String, dynamic> Model = Map();
    Model['FID'] = 0;
    Model['FBillType'] = {"FNUMBER": "JSJSD01_SYS"};
    Model['FDate'] = FDate;

    // 取第一个非空分录的组织信息（假设所有分录同组织）
    var firstEntry = matchingEntries.firstWhere((e) => e != null, orElse: () => null);
    if (firstEntry != null) {
      Model['FStockOrgId'] = {"FNumber": firstEntry[8]};  // FStockOrgId.FNumber
      Model['FSaleOrgId'] = {"FNumber": firstEntry[1]};   // FSaleOrgId.FNumber
      Model['FCustId'] = {"FNumber": firstEntry[16]};     // 原索引16可能是客户编号？需要根据实际调整，此处暂取 keeper 编号，实际客户可能需额外处理，建议根据业务确认。
    } else {
      // 无任何分录（全为0数量），使用默认组织
      Model['FStockOrgId'] = {"FNumber": fOrgID};
      Model['FSaleOrgId'] = {"FNumber": fOrgID};
      Model['FCustId'] = {"FNumber": keeperNo};
    }

    // 用户ID：取第一个分录的头用户ID，若无则置空
    Model['F_VZSF_UserId'] = firstEntry != null ? {"FUserID": firstEntry[30]} : null;
    Model['F_VZSF_Text_PDA'] = "PDA-";
    Model['F_VZSF_YSDH'] = firstEntry![31];

    var FEntity = [];
    var FSelBill = [];

    for (int i = 0; i < hobby.length; i++) {
      var element = hobby[i];
      if (element[3]['value']['value'] == '0' || element[4]['value']['value'] == '') {
        continue; // 跳过无效行
      }

      var entry = matchingEntries[i];
      if (entry == null) continue; // 理论上不会走到这里

      Map<String, dynamic> FEntityItem = Map();
      Map<String, dynamic> FSelBillEntity = Map();

      FEntityItem['FMaterialId'] = {"FNumber": element[0]['value']['value']};
      FEntityItem['FUnitID'] = {"FNumber": element[2]['value']['value']};
      FEntityItem['FTaxPrice'] = entry[23]; // FTaxPrice
      FEntityItem['FTaxRate'] = entry[24];   // FTaxRate
      FEntityItem['FStockId'] = {"FNumber": element[4]['value']['value']};
      FEntityItem['FLot'] = {"FNumber": element[5]['value']['value']};
      FEntityItem['FSrcType'] = "STK_TransferDirect";
      FEntityItem['FSrcBillNo'] = entry[0];   // FBillNo
      FEntityItem['FOrderNo'] = entry[28];    // FOrderNo
      FEntityItem['F_VZSF_Text'] = contractNo; // 使用头字段合同编号

      FEntityItem['FSettleType'] = "DELIVER";

      // 仓位处理
      if (element[6]['value']['hide']) {
        Map<String, dynamic> stockMap = Map();
        stockMap['FormId'] = 'BD_STOCK';
        stockMap['FieldKeys'] = 'FFlexNumber';
        stockMap['FilterString'] = "FNumber = '" + element[4]['value']['value'] + "'";
        Map<String, dynamic> stockDataMap = Map();
        stockDataMap['data'] = stockMap;
        String res = await CurrencyEntity.polling(stockDataMap);
        var stockRes = jsonDecode(res);
        if (stockRes.isNotEmpty) {
          var postionList = element[6]['value']['value'].split(".");
          FEntityItem['FStockLocId'] = {};
          for (int idx = 0; idx < postionList.length; idx++) {
            FEntityItem['FStockLocId']["FSTOCKLOCID__" + stockRes[idx][0]] = {
              "FNumber": postionList[idx]
            };
          }
        }
      }

      FEntityItem['FQty'] = element[3]['value']['value'];

      // 序列号子实体
      var fSerialSub = [];
      var kingDeeCode = element[0]['value']['kingDeeCode'];
      for (var code in kingDeeCode) {
        Map<String, dynamic> subObj = Map();
        var parts = code.split("-");
        if (parts.length > 2) {
          subObj['FSerialNo'] = (parts.length > 3) ? '${parts[2]}-${parts[3]}' : parts[2];
        } else {
          subObj['FSerialNo'] = code;
        }
        fSerialSub.add(subObj);
      }

      FSelBillEntity['FSerialSubEntity'] = fSerialSub;
      FSelBillEntity['FSelBillEntity_Link'] = [
        {
          "FSelBillEntity_Link_FRuleId": "TransferDirect-ConsignmentSettle",
          "FSelBillEntity_Link_FSTableName": "T_STK_STKTRANSFERINENTRY",
          "FSelBillEntity_Link_FSBillId": entry[15], // FID
          "FSelBillEntity_Link_FSId": entry[4],       // FBillEntry_FEntryId
          "FSelBillEntity_Link_FBaseSettleQtyRow": element[3]['value']['value'],
          "FSelBillEntity_Link_FSalBaseQtyRow": element[3]['value']['value'],
        }
      ];

      FEntity.add(FEntityItem);
      FSelBill.add(FSelBillEntity);
    }

    if (FEntity.isEmpty) {
      setState(() => isSubmit = false);
      ToastUtil.showInfo('请输入数量和仓库');
      return;
    }

    Model['FConsigSetEntity'] = FEntity;
    Model['FSelBillEntity'] = FSelBill;
    orderMap['Model'] = Model;
    dataMap['data'] = orderMap;
    var saveData = jsonEncode(dataMap);
    print(jsonEncode(dataMap));
    String order = await SubmitEntity.save(dataMap);
    var res = jsonDecode(order);

    if (res['Result']['ResponseStatus']['IsSuccess']) {
      Map<String, dynamic> submitMap = {
        "formid": "SAL_ConsignmentSettle",
        "data": {'Ids': res['Result']['ResponseStatus']['SuccessEntitys'][0]['Id']}
      };
      // 提交
      HandlerOrder.orderHandler(context, submitMap, 1, "SAL_ConsignmentSettle", SubmitEntity.submit(submitMap)).then((submitResult) async {
        if (submitResult) {
          // 条码清单更新
          var errorMsg = "";
          if (fBarCodeList == 1) {
            for (int i = 0; i < hobby.length; i++) {
              if (hobby[i][3]['value']['value'] != '0') {
                var kingDeeCode = hobby[i][0]['value']['kingDeeCode'];
                for (int j = 0; j < kingDeeCode.length; j++) {
                  Map<String, dynamic> dataCodeMap = Map();
                  dataCodeMap['formid'] = 'QDEP_Cust_BarCodeList';
                  Map<String, dynamic> orderCodeMap = Map();
                  orderCodeMap['NeedReturnFields'] = [];
                  orderCodeMap['IsDeleteEntry'] = false;
                  Map<String, dynamic> codeModel = Map();
                  var itemCode = kingDeeCode[j].split("-");
                  codeModel['FID'] = itemCode[0];
                  Map<String, dynamic> codeFEntityItem = Map();
                  codeFEntityItem['FBillDate'] = FDate;
                  codeFEntityItem['FOutQty'] = itemCode[1];
                  // 从 matchingEntries 获取对应单号
                  codeFEntityItem['FEntryBillNo'] = matchingEntries[i] != null ? matchingEntries[i]![0] : "";
                  codeFEntityItem['FEntryStockID'] = {
                    "FNUMBER": hobby[i][4]['value']['value']
                  };
                  if (hobby[i][6]['value']['hide']) {
                    codeFEntityItem['FStockLocNumber'] = hobby[i][6]['value']['value'];
                    Map<String, dynamic> stockMap = Map();
                    stockMap['FormId'] = 'BD_STOCK';
                    stockMap['FieldKeys'] = 'FFlexNumber';
                    stockMap['FilterString'] = "FNumber = '" + hobby[i][4]['value']['value'] + "'";
                    Map<String, dynamic> stockDataMap = Map();
                    stockDataMap['data'] = stockMap;
                    String res = await CurrencyEntity.polling(stockDataMap);
                    var stockRes = jsonDecode(res);
                    if (stockRes.length > 0) {
                      var postionList = hobby[i][6]['value']['value'].split(".");
                      codeFEntityItem['FStockLocID'] = {};
                      var positonIndex = 0;
                      for (var dimension in postionList) {
                        codeFEntityItem['FStockLocID']["FSTOCKLOCID__" + stockRes[positonIndex][0]] = {
                          "FNumber": dimension
                        };
                        positonIndex++;
                      }
                    }
                  }
                  var codeFEntity = [codeFEntityItem];
                  codeModel['FEntity'] = codeFEntity;
                  orderCodeMap['Model'] = codeModel;
                  dataCodeMap['data'] = orderCodeMap;
                  print(dataCodeMap);
                  String codeRes = await SubmitEntity.save(dataCodeMap);
                  var barcodeRes = jsonDecode(codeRes);
                  if (!barcodeRes['Result']['ResponseStatus']['IsSuccess']) {
                    errorMsg += "错误反馈：" + itemCode[1] + ":" + barcodeRes['Result']['ResponseStatus']['Errors'][0]['Message'];
                  }
                  print(codeRes);
                }
              }
            }
          }
          if (errorMsg.isNotEmpty) {
            ToastUtil.errorDialog(context, errorMsg);
            setState(() => isSubmit = false);
          } else {
            setState(() {
              hobby.clear();
              orderDate.clear();
              FBillNo = '';
              ToastUtil.showInfo('提交成功');
              Navigator.of(context).pop("refresh");
            });
          }
        } else {
          setState(() => isSubmit = false);
        }
      });
    } else {
      setState(() => isSubmit = false);
      ToastUtil.errorDialog(context, res['Result']['ResponseStatus']['Errors'][0]['Message']);
    }
  }

  /// 确认提交提示对话框
  Future<void> _showSumbitDialog() async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: new Text("是否提交"),
            actions: <Widget>[
              new FlatButton(
                child: new Text('不了'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              new FlatButton(
                child: new Text('确定'),
                onPressed: () {
                  Navigator.of(context).pop();
                  saveOrder();
                },
              )
            ],
          );
        });
  }

  //扫码函数
  Future scan() async {
    String cameraScanResult = await scanner.scan();
    getScan(cameraScanResult);
    print(cameraScanResult);
  }

  void getScan(String scan) async {
    _onEvent(scan);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterEasyLoading(
      child: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: scan,
            tooltip: 'Increment',
            child: Icon(Icons.filter_center_focus),
          ),
          appBar: AppBar(
            title: Text("结算"),
            centerTitle: true,
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: ListView(children: <Widget>[
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: Text("单号：$FBillNo"),
                        ),
                      ),
                      divider,
                    ],
                  ),
                  Visibility(
                    maintainSize: false,
                    maintainState: false,
                    maintainAnimation: false,
                    visible: isScanWork,
                    child: Column(
                      children: [
                        Container(
                          color: Colors.white,
                          child: ListTile(
                            title: Text("客户：$cusName"),
                          ),
                        ),
                        divider,
                      ],
                    ),
                  ),
                  _dateItem('日期：', DateMode.YMD),
                  // 保管者下拉（始终显示）
                  _item('保管者:', keeperDisplayList, selectedKeeperDisplay, 'keeper'),
                  // 合同编号下拉（始终显示）
                  _item('合同编号:', contractList, selectedContract, 'contract'),
                  /*Visibility(
                    maintainSize: false,
                    maintainState: false,
                    maintainAnimation: false,
                    visible: !isScanWork,
                    child: _item('客户:', this.customerList, this.customerName, 'customer'),
                  ),*/
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: TextField(
                            maxLines: 1,
                            decoration: InputDecoration(
                              hintText: "备注",
                              border: OutlineInputBorder(),
                            ),
                            controller: this._remarkContent,
                            onChanged: (value) {
                              setState(() {
                                _remarkContent.value = TextEditingValue(
                                    text: value,
                                    selection: TextSelection.fromPosition(TextPosition(
                                        affinity: TextAffinity.downstream,
                                        offset: value.length)));
                              });
                            },
                          ),
                        ),
                      ),
                      divider,
                    ],
                  ),
                  Column(
                    children: this._getHobby(),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: RaisedButton(
                        padding: EdgeInsets.all(15.0),
                        child: Text("保存"),
                        color: this.isSubmit?Colors.grey:Theme.of(context).primaryColor,
                        textColor: Colors.white,
                        onPressed: () async=> this.isSubmit ? null : _showSumbitDialog(),
                      ),
                    ),
                  ],
                ),
              )
            ],
          )),
    );
  }
}