import 'dart:convert';
import 'package:date_format/date_format.dart';
import 'package:fzwm_apl/model/currency_entity.dart';
import 'package:fzwm_apl/model/submit_entity.dart';
import 'package:fzwm_apl/utils/handler_order.dart';
import 'package:fzwm_apl/utils/refresh_widget.dart';
import 'package:fzwm_apl/utils/text.dart';
import 'package:fzwm_apl/utils/toast_util.dart';
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

class RetrievalDetail extends StatefulWidget {
  var FBillNo;

  RetrievalDetail({Key? key, @required this.FBillNo}) : super(key: key);

  @override
  _RetrievalDetailState createState() => _RetrievalDetailState(FBillNo);
}

class _RetrievalDetailState extends State<RetrievalDetail> {
  var _remarkContent = new TextEditingController();
  GlobalKey<PartRefreshWidgetState> globalKey = GlobalKey();
  GlobalKey<TextWidgetState> textKey = GlobalKey();
  final _textNumber = TextEditingController();
  var checkItem;
  String FBillNo = '';
  String FSaleOrderNo = '';
  String cusName = '';
  String FName = '';
  String FNumber = '';
  String FDate = '';
  String FLinkMan = '';
  String FHeadLocId = '';
  String FLinkPhone = '';
  var customerName;
  var customerNumber;
  var isSubmit = false;
  var show = false;
  var isScanWork = false;
  var fBarCodeList;
  var checkData;
  var fOrgID;
  var checkDataChild;
  var selectData = {
    DateMode.YMD: '',
  };
  var customerList = [];
  List<dynamic> customerListObj = [];
  var stockList = [];
  List<dynamic> stockListObj = [];
  List<dynamic> orderDate = [];
  List<dynamic> materialDate = [];
  final divider = Divider(height: 1, indent: 20);
  final rightIcon = Icon(Icons.keyboard_arrow_right);
  final scanIcon = Icon(Icons.filter_center_focus);
  static const scannerPlugin =
      const EventChannel('com.shinow.pda_scanner/plugin');
  StreamSubscription? _subscription;
  var _code;
  var _FNumber;
  var fBillNo;

  _RetrievalDetailState(FBillNo) {
    if (FBillNo != null) {
      this.fBillNo = FBillNo['value'];
      this.getOrderList();
      isScanWork = true;
    } else {
      isScanWork = false;
      this.fBillNo = '';
      getCustomer();
      getStockList();
    }
  }

  @override
  void initState() {
    super.initState();
    // 开启监听
    if (_subscription == null) {
      _subscription = scannerPlugin
          .receiveBroadcastStream()
          .listen(_onEvent, onError: _onError);
    }
    /*getWorkShop();*/
    EasyLoading.dismiss();
  }

  //获取客户
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

  //获取仓库
  getStockList() async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'BD_STOCK';
    userMap['FieldKeys'] = 'FStockID,FName,FNumber,FIsOpenLocation';
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    if (fOrgID == null) {
      this.fOrgID = deptData[1];
    }
    userMap['FilterString'] =
        "FForbidStatus = 'A' and FUseOrgId.FNumber ='" + fOrgID + "'";
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

    /// 取消监听
    if (_subscription != null) {
      _subscription!.cancel();
    }
  }

  // 查询数据集合
  List hobby = [];
  List fNumber = [];

  getOrderList() async {
    EasyLoading.show(status: 'loading...');
    Map<String, dynamic> userMap = Map();
    print(fBillNo);
    userMap['FilterString'] = "fBillNo='$fBillNo'";
    userMap['FormId'] = 'SAL_DELIVERYNOTICE';
    userMap['OrderString'] = 'FMaterialId.FNumber ASC';
    userMap['FieldKeys'] =
        'FBillNo,FSaleOrgId.FNumber,FSaleOrgId.FName,FDate,FEntity_FEntryId,FMaterialId.FNumber,FMaterialId.FName,FMaterialId.FSpecification,FDeliveryOrgID.FNumber,FDeliveryOrgID.FName,FUnitId.FNumber,FUnitId.FName,FQty,FDeliveryDate,FRemainOutQty,FID,FCustomerID.FNumber,FCustomerID.FName,FStockID.FName,FStockID.FNumber,FLot.FNumber,FStockID.FIsOpenLocation,FMaterialId.FIsBatchManage,FTaxPrice,FEntryTaxRate,FAllAmount,FLinkMan,FHeadLocId.FName,FLinkPhone,F_UYEP_UserId,FSrcBillNo,F_UYEP_Date,F_UYEP_Text,FNote,FNoteEntry,FPrice';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    orderDate = [];
    orderDate = jsonDecode(order);
    DateTime dateTime = DateTime.now();
    FDate = formatDate(DateTime.now(), [
      yyyy,
      "-",
      mm,
      "-",
      dd,
    ]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [
      yyyy,
      "-",
      mm,
      "-",
      dd,
    ]);
    if (orderDate.length > 0) {
      this.FBillNo = orderDate[0][0];
      this.cusName = orderDate[0][17];
      this.fOrgID = orderDate[0][8];
      this.FLinkMan = orderDate[0][26];
      this.FHeadLocId = orderDate[0][27];
      this.FLinkPhone = orderDate[0][28];
      hobby = [];
      orderDate.forEach((value) {
        fNumber.add(value[5]);
        List arr = [];
        arr.add({
          "title": "物料名称",
          "name": "FMaterial",
          "isHide": false,
          "value": {
            "label": value[6] + "- (" + value[5] + ")",
            "value": value[5],
            "barcode": [],
            "kingDeeCode": [],
            "surplus": value[12],
            "scanCode": []
          }
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
          "title": "出库数量",
          "name": "FRemainOutQty",
          "isHide": false,
          "value": {"label": "0", "value": "0"}
        });
        arr.add({
          "title": "仓库",
          "name": "FStockId",
          "isHide": false,
          /*"value": {"label": value[18], "value": value[19]}*/
          "value": {"label": "", "value": ""}
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
          "value": {"label": "", "value": "", "hide": value[21]}
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
          "title": "未出库数量",
          "name": "",
          "isHide": false,
          "value": {"label": value[12], "value": value[12]}
        });
        arr.add({
          "title": "最后扫描数量",
          "name": "FLastQty",
          "isHide": false,
          "value": {"label": "0", "value": "0"}
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
    //_onEvent("247240621320073");
    /*_onEvent("34TI4lY5kQOIQxGWehV+aj1NEKgIMLqSkaAHBHK+qA0FqxbBy2zc9A==");*/
  }

  void _onEvent(event) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var deptData = sharedPreferences.getString('menuList');
    var menuList = new Map<dynamic, dynamic>.from(jsonDecode(deptData));
    fBarCodeList = menuList['FBarCodeList'];
    if (event == "") {
      return;
    }
    if (fBarCodeList == 1) {
      if(event.split('-').length>2){

        getMaterialListT(event,event.split('-')[2]);
      }else {
        if (event.length > 15) {
          Map<String, dynamic> barcodeMap = Map();
          barcodeMap['FilterString'] = "FBarCodeEn='" + event + "'";
          barcodeMap['FormId'] = 'QDEP_Cust_BarCodeList';
          barcodeMap['FieldKeys'] =
          'FID,FInQtyTotal,FOutQtyTotal,FEntity_FEntryId,FRemainQty,FBarCodeQty,FStockID.FName,FStockID.FNumber,FMATERIALID.FNUMBER,FOwnerID.FNumber,FBarCode,FSN';
          Map<String, dynamic> dataMap = Map();
          dataMap['data'] = barcodeMap;
          String order = await CurrencyEntity.polling(dataMap);
          var barcodeData = jsonDecode(order);
          if (barcodeData.length > 0) {
            if (barcodeData[0][4] > 0) {
              var msg = "";
              var orderIndex = 0;
              for (var value in orderDate) {
                if (value[5] == barcodeData[0][8]) {
                  msg = "";
                  if (fNumber.lastIndexOf(barcodeData[0][8]) == orderIndex) {
                    break;
                  }
                } else {
                  msg = '条码不在单据物料中';
                }
                orderIndex++;
              }
              ;
              if (msg == "") {
                _code = event;
                this.getMaterialList(
                    barcodeData, barcodeData[0][10], barcodeData[0][11]);


                print("ChannelPage: $event");
              } else {
                ToastUtil.showInfo(msg);
              }
            } else {
              ToastUtil.showInfo('该条码已出库或没入库，数量为零');
            }
          } else {
            ToastUtil.showInfo('条码不在条码清单中');
          }
        }else{
          getMaterialListTH(event,event.substring(9,15));
        }
      }
    } else {
      _code = event;
      this.getMaterialList("", _code, "");
      print("ChannelPage: $event");
    }
    print("ChannelPage: $event");
  }

  void _onError(Object error) {
    setState(() {
      _code = "扫描异常";
    });
  }

  getMaterialList(barcodeData, code, fsn) async {
    Map<String, dynamic> userMap = Map();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    var scanCode = code.split(";");
    userMap['FilterString'] = "FNumber='" +
        barcodeData[0][8] +
        "' and FForbidStatus = 'A' and FUseOrgId.FNumber = '" +
        deptData[1] +
        "'";
    userMap['FormId'] = 'BD_MATERIAL';
    userMap['FieldKeys'] =
        'FMATERIALID,FName,FNumber,FSpecification,FBaseUnitId.FName,FBaseUnitId.FNumber,FIsBatchManage,FCategoryID.FNumber';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    materialDate = [];
    materialDate = jsonDecode(order);
    FDate = formatDate(DateTime.now(), [
      yyyy,
      "-",
      mm,
      "-",
      dd,
    ]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [
      yyyy,
      "-",
      mm,
      "-",
      dd,
    ]);
    if (materialDate.length > 0) {
      Map<String, dynamic> serialMap = Map();
      serialMap['FormId'] = 'BD_SerialMainFile';
      serialMap['FieldKeys'] = 'FStockStatus';
      serialMap['FilterString'] = "FNumber = '" + barcodeData[0][11] + "' and FMaterialID.FNumber = '" + materialDate[0][2] + "'";
      Map<String, dynamic> serialDataMap = Map();
      serialDataMap['data'] = serialMap;
      String serialRes = await CurrencyEntity.polling(serialDataMap);
      var serialJson = jsonDecode(serialRes);
      if ((serialJson.length > 1 || (serialJson.length > 0 && serialJson[0][0] != "1"))) {// && materialDate[0][7] != '001'
        ToastUtil.showInfo('该序列号已出库或未入库');
        return;
      }
      var number = 0;
      var barCodeScan = [];
      if (fBarCodeList == 1) {
        barCodeScan = barcodeData[0];
        barCodeScan.add(barCodeScan[4]);
        barCodeScan[4] = barCodeScan[4].toString();
      } else {
        barCodeScan = scanCode;
        barCodeScan.add(barCodeScan[3]);
      }
      var barcodeNum = scanCode[3];
      var residue = double.parse(scanCode[3]);
      var hobbyIndex = 0;
      for (var element in hobby) {
        hobbyIndex++;
        //判断是否启用批号
        if (element[5]['isHide']) {
          //不启用  && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                              double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item =
                      barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              //判断扫描数量是否大于单据数量
              if (double.parse(element[3]['value']['label']) >=
                  element[9]['value']['label']) {
                continue;
              } else {
                //判断条码数量
                if ((double.parse(element[3]['value']['label']) + residue) >
                        0 &&
                    residue > 0) {
                  //判断条码是否重复
                  if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                    //判断末尾
                    if (fNumber.lastIndexOf(
                            element[0]['value']['value'].toString()) ==
                        (hobbyIndex - 1)) {
                      var item = barCodeScan[0].toString() +
                          "-" +
                          residue.toString() +
                          "-" +
                          fsn;
                      element[10]['value']['label'] = residue.toString();
                      element[10]['value']['value'] = residue.toString();
                      element[3]['value']['label'] =
                          (double.parse(element[3]['value']['label']) + residue)
                              .toString();
                      element[3]['value']['value'] =
                          element[3]['value']['label'];
                      residue = (residue * 100 -
                              double.parse(element[10]['value']['value']) *
                                  100) /
                          100;
                      element[0]['value']['surplus'] =
                          (element[9]['value']['value'] * 100 -
                                  double.parse(element[3]['value']['label']) *
                                      100) /
                              100;
                      element[0]['value']['kingDeeCode'].add(item);
                      element[0]['value']['scanCode'].add(code);
                    } else {
                      //判断剩余数量是否大于扫码数量
                      if (element[0]['value']['surplus'] >= residue) {
                        var item = barCodeScan[0].toString() +
                            "-" +
                            residue.toString() +
                            "-" +
                            fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                    residue)
                                .toString();
                        element[3]['value']['value'] =
                            element[3]['value']['label'];
                        residue = 0.0;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                    double.parse(element[3]['value']['label']) *
                                        100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        var item = barCodeScan[0].toString() +
                            "-" +
                            element[0]['value']['surplus'].toString() +
                            "-" +
                            fsn;
                        element[10]['value']['label'] =
                            element[0]['value']['surplus'].toString();
                        element[10]['value']['value'] =
                            element[0]['value']['surplus'].toString();
                        element[3]['value']['label'] = (element[0]['value']
                                    ['surplus'] +
                                double.parse(element[3]['value']['label']))
                            .toString();
                        element[3]['value']['value'] =
                            element[3]['value']['label'];
                        residue = (residue * 100 -
                                double.parse(element[10]['value']['value']) *
                                    100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                    double.parse(element[3]['value']['label']) *
                                        100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        } else {
          //启用批号 && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  if (element[5]['value']['value'] == "") {
                    element[5]['value']['label'] = scanCode[1];
                    element[5]['value']['value'] = scanCode[1];
                  }
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                              double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item =
                      barCodeScan[0].toString() + "-" + barcodeNum + "-" + fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              if (element[5]['value']['value'] == scanCode[1]) {
                //判断扫描数量是否大于单据数量
                if (double.parse(element[3]['value']['label']) >=
                    element[9]['value']['label']) {
                  continue;
                } else {
                  //判断条码数量
                  if ((double.parse(element[3]['value']['label']) + residue) >
                          0 &&
                      residue > 0) {
                    //判断条码是否重复
                    if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                      //判断末尾
                      if (fNumber.lastIndexOf(
                              element[0]['value']['value'].toString()) ==
                          (hobbyIndex - 1)) {
                        var item = barCodeScan[0].toString() +
                            "-" +
                            residue.toString() +
                            "-" +
                            fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                    residue)
                                .toString();
                        element[3]['value']['value'] =
                            element[3]['value']['label'];
                        residue = (residue * 100 -
                                double.parse(element[10]['value']['value']) *
                                    100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                    double.parse(element[3]['value']['label']) *
                                        100) /
                                100;
                        ;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        //判断剩余数量是否大于扫码数量
                        if (element[0]['value']['surplus'] >= residue) {
                          var item = barCodeScan[0].toString() +
                              "-" +
                              residue.toString() +
                              "-" +
                              fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                      residue)
                                  .toString();
                          element[3]['value']['value'] =
                              element[3]['value']['label'];
                          residue = 0.0;
                          element[0]['value']['surplus'] = (element[9]['value']
                                          ['value'] *
                                      100 -
                                  double.parse(element[3]['value']['label']) *
                                      100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          var item = barCodeScan[0].toString() +
                              "-" +
                              element[0]['value']['surplus'].toString() +
                              "-" +
                              fsn;
                          element[10]['value']['label'] =
                              element[0]['value']['surplus'].toString();
                          element[10]['value']['value'] =
                              element[0]['value']['surplus'].toString();
                          element[3]['value']['label'] = (element[0]['value']
                                      ['surplus'] +
                                  double.parse(element[3]['value']['label']))
                              .toString();
                          element[3]['value']['value'] =
                              element[3]['value']['label'];
                          residue = (residue * 100 -
                                  double.parse(element[10]['value']['value']) *
                                      100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                                          ['value'] *
                                      100 -
                                  double.parse(element[3]['value']['label']) *
                                      100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        }
                      }
                    }
                  }
                }
              } else {
                if (element[5]['value']['value'] == "") {
                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                  //判断扫描数量是否大于单据数量
                  if (double.parse(element[3]['value']['label']) >=
                      element[9]['value']['label']) {
                    continue;
                  } else {
                    //判断条码数量
                    if ((double.parse(element[3]['value']['label']) + residue) >
                            0 &&
                        residue > 0) {
                      //判断条码是否重复
                      if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                        //判断末尾
                        if (fNumber.lastIndexOf(
                                element[0]['value']['value'].toString()) ==
                            (hobbyIndex - 1)) {
                          var item = barCodeScan[0].toString() +
                              "-" +
                              residue.toString() +
                              "-" +
                              fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                      residue)
                                  .toString();
                          element[3]['value']['value'] =
                              element[3]['value']['label'];
                          residue = (residue * 100 -
                                  double.parse(element[10]['value']['value']) *
                                      100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                                          ['value'] *
                                      100 -
                                  double.parse(element[3]['value']['label']) *
                                      100) /
                              100;
                          ;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          //判断剩余数量是否大于扫码数量
                          if (element[0]['value']['surplus'] >= residue) {
                            var item = barCodeScan[0].toString() +
                                "-" +
                                residue.toString() +
                                "-" +
                                fsn;
                            element[10]['value']['label'] = residue.toString();
                            element[10]['value']['value'] = residue.toString();
                            element[3]['value']['label'] =
                                (double.parse(element[3]['value']['label']) +
                                        residue)
                                    .toString();
                            element[3]['value']['value'] =
                                element[3]['value']['label'];
                            residue = 0.0;
                            element[0]['value']['surplus'] = (element[9]
                                            ['value']['value'] *
                                        100 -
                                    double.parse(element[3]['value']['label']) *
                                        100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          } else {
                            var item = barCodeScan[0].toString() +
                                "-" +
                                element[0]['value']['surplus'].toString() +
                                "-" +
                                fsn;
                            element[10]['value']['label'] =
                                element[0]['value']['surplus'].toString();
                            element[10]['value']['value'] =
                                element[0]['value']['surplus'].toString();
                            element[3]['value']['label'] = (element[0]['value']
                                        ['surplus'] +
                                    double.parse(element[3]['value']['label']))
                                .toString();
                            element[3]['value']['value'] =
                                element[3]['value']['label'];
                            residue = (residue * 100 -
                                    double.parse(
                                            element[10]['value']['value']) *
                                        100) /
                                100;
                            element[0]['value']['surplus'] = (element[9]
                                            ['value']['value'] *
                                        100 -
                                    double.parse(element[3]['value']['label']) *
                                        100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          }
                        }
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        }
      }
      if (number == 0 && this.fBillNo == "") {
        materialDate.forEach((value) {
          List arr = [];
          arr.add({
            "title": "单据编号",
            "name": "FBillNo",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "销售组织",
            "name": "FSaleOrgId",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "客户",
            "name": "FSaleOrgId",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "单据日期",
            "name": "FDate",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "物料名称",
            "name": "FMaterial",
            "isHide": false,
            "value": {
              "label": value[1] + "- (" + value[2] + ")",
              "value": value[2],
              "barcode": [_code]
            }
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
            "title": "出库数量",
            "name": "FRealQty",
            "isHide": false,
            "value": {"label": "0", "value": "0"}
          });
          arr.add({
            "title": "数量",
            "name": "FRemainOutQty",
            "isHide": false,
            "value": {"label": "1", "value": "1"}
          });
          arr.add({
            "title": "要货日期",
            "name": "FDeliveryDate",
            "isHide": true,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "仓库",
            "name": "FStockID",
            "isHide": false,
            "value": {"label": "", "value": ""}
          });
          arr.add({
            "title": "批号",
            "name": "FLot",
            "isHide": value[6] != true,
            "value": {
              "label": value[6] ? (scanCode.length > 1 ? scanCode[1] : '') : '',
              "value": value[6] ? (scanCode.length > 1 ? scanCode[1] : '') : ''
            }
          });
          arr.add({
            "title": "仓位",
            "name": "FStockLocID",
            "isHide": false,
            "value": {"label": "", "value": "", "hide": false}
          });
          arr.add({
            "title": "操作",
            "name": "",
            "isHide": false,
            "value": {"label": "", "value": ""}
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
  getMaterialListT(code, fsn) async {
    Map<String, dynamic> userMap = Map();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    userMap['FilterString'] = "F_UYEP_GYSTM='"+code.split('-')[0]+"' and FForbidStatus = 'A' and FUseOrgId.FNumber = '"+deptData[1]+"'";
    userMap['FormId'] = 'BD_MATERIAL';
    userMap['FieldKeys'] =
    'FMATERIALID,FName,FNumber,FSpecification,FBaseUnitId.FName,FBaseUnitId.FNumber,FIsBatchManage,FCategoryID.FNumber';/*,SubHeadEntity1.FStoreUnitID.FNumber*/
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    materialDate = [];
    materialDate = jsonDecode(order);
    var scanCode = [materialDate[0][2],code.split("-")[1],"","","","N"];
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    if (materialDate.length > 0) {
      Map<String, dynamic> serialMap = Map();
      serialMap['FormId'] = 'BD_SerialMainFile';
      serialMap['FieldKeys'] = 'FStockStatus';
      serialMap['FilterString'] = "FNumber = '" + code.split('-')[2] + "' and FMaterialID.FNumber = '" + materialDate[0][2] + "'";
      Map<String, dynamic> serialDataMap = Map();
      serialDataMap['data'] = serialMap;
      String serialRes = await CurrencyEntity.polling(serialDataMap);
      var serialJson = jsonDecode(serialRes);
      if ((serialJson.length > 1 || (serialJson.length > 0 && serialJson[0][0] != "1"))) {// && materialDate[0][7] != '001'
        ToastUtil.showInfo('该序列号已出库或未入库');
        return;
      }
      var msg = "";
      var orderIndex = 0;
      for (var value in orderDate) {
        if(value[5] == materialDate[0][2]){
          msg = "";
          if(fNumber.lastIndexOf(materialDate[0][2])  == orderIndex){
            break;
          }
        }else{
          msg = '条码不在单据物料中';
        }
        orderIndex++;
      };
      if(msg !=  ""){
        ToastUtil.showInfo(msg);
        return;
      }
      var number = 0;
      var barcodeNum = '1';
      var hobbyIndex = 0;
      var residue = 1.0;
      for (var element in hobby) {
        hobbyIndex++;
        //判断是否启用批号
        if (element[5]['isHide']) {
          //不启用  && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                          double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item = fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              //判断扫描数量是否大于单据数量
              if (double.parse(element[3]['value']['label']) >=
                  element[9]['value']['label']) {
                continue;
              } else {
                //判断条码数量
                if ((double.parse(element[3]['value']['label']) + residue) >
                    0 &&
                    residue > 0) {
                  //判断条码是否重复
                  if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                    //判断末尾
                    if (fNumber.lastIndexOf(
                        element[0]['value']['value'].toString()) ==
                        (hobbyIndex - 1)) {
                      var item = fsn;
                      element[10]['value']['label'] = residue.toString();
                      element[10]['value']['value'] = residue.toString();
                      element[3]['value']['label'] =
                          (double.parse(element[3]['value']['label']) + residue)
                              .toString();
                      element[3]['value']['value'] =
                      element[3]['value']['label'];
                      residue = (residue * 100 -
                          double.parse(element[10]['value']['value']) *
                              100) /
                          100;
                      element[0]['value']['surplus'] =
                          (element[9]['value']['value'] * 100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                      element[0]['value']['kingDeeCode'].add(item);
                      element[0]['value']['scanCode'].add(code);
                    } else {
                      //判断剩余数量是否大于扫码数量
                      if (element[0]['value']['surplus'] >= residue) {
                        var item = fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                residue)
                                .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = 0.0;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        var item = fsn;
                        element[10]['value']['label'] =
                            element[0]['value']['surplus'].toString();
                        element[10]['value']['value'] =
                            element[0]['value']['surplus'].toString();
                        element[3]['value']['label'] = (element[0]['value']
                        ['surplus'] +
                            double.parse(element[3]['value']['label']))
                            .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = (residue * 100 -
                            double.parse(element[10]['value']['value']) *
                                100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        } else {
          //启用批号 && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  if (element[5]['value']['value'] == "") {
                    element[5]['value']['label'] = scanCode[1];
                    element[5]['value']['value'] = scanCode[1];
                  }
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                          double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item = fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              if (element[5]['value']['value'] == scanCode[1]) {
                //判断扫描数量是否大于单据数量
                if (double.parse(element[3]['value']['label']) >=
                    element[9]['value']['label']) {
                  continue;
                } else {
                  //判断条码数量
                  if ((double.parse(element[3]['value']['label']) + residue) >
                      0 &&
                      residue > 0) {
                    //判断条码是否重复
                    if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                      //判断末尾
                      if (fNumber.lastIndexOf(
                          element[0]['value']['value'].toString()) ==
                          (hobbyIndex - 1)) {
                        var item = fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                residue)
                                .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = (residue * 100 -
                            double.parse(element[10]['value']['value']) *
                                100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        ;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        //判断剩余数量是否大于扫码数量
                        if (element[0]['value']['surplus'] >= residue) {
                          var item = fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                  residue)
                                  .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = 0.0;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          var item = fsn;
                          element[10]['value']['label'] =
                              element[0]['value']['surplus'].toString();
                          element[10]['value']['value'] =
                              element[0]['value']['surplus'].toString();
                          element[3]['value']['label'] = (element[0]['value']
                          ['surplus'] +
                              double.parse(element[3]['value']['label']))
                              .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = (residue * 100 -
                              double.parse(element[10]['value']['value']) *
                                  100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        }
                      }
                    }
                  }
                }
              } else {
                if (element[5]['value']['value'] == "") {
                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                  //判断扫描数量是否大于单据数量
                  if (double.parse(element[3]['value']['label']) >=
                      element[9]['value']['label']) {
                    continue;
                  } else {
                    //判断条码数量
                    if ((double.parse(element[3]['value']['label']) + residue) >
                        0 &&
                        residue > 0) {
                      //判断条码是否重复
                      if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                        //判断末尾
                        if (fNumber.lastIndexOf(
                            element[0]['value']['value'].toString()) ==
                            (hobbyIndex - 1)) {
                          var item = fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                  residue)
                                  .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = (residue * 100 -
                              double.parse(element[10]['value']['value']) *
                                  100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          ;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          //判断剩余数量是否大于扫码数量
                          if (element[0]['value']['surplus'] >= residue) {
                            var item = fsn;
                            element[10]['value']['label'] = residue.toString();
                            element[10]['value']['value'] = residue.toString();
                            element[3]['value']['label'] =
                                (double.parse(element[3]['value']['label']) +
                                    residue)
                                    .toString();
                            element[3]['value']['value'] =
                            element[3]['value']['label'];
                            residue = 0.0;
                            element[0]['value']['surplus'] = (element[9]
                            ['value']['value'] *
                                100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          } else {
                            var item = fsn;
                            element[10]['value']['label'] =
                                element[0]['value']['surplus'].toString();
                            element[10]['value']['value'] =
                                element[0]['value']['surplus'].toString();
                            element[3]['value']['label'] = (element[0]['value']
                            ['surplus'] +
                                double.parse(element[3]['value']['label']))
                                .toString();
                            element[3]['value']['value'] =
                            element[3]['value']['label'];
                            residue = (residue * 100 -
                                double.parse(
                                    element[10]['value']['value']) *
                                    100) /
                                100;
                            element[0]['value']['surplus'] = (element[9]
                            ['value']['value'] *
                                100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          }
                        }
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        }
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
  getMaterialListTH(code, fsn) async {
    Map<String, dynamic> userMap = Map();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];

    userMap['FilterString'] = "F_UYEP_GYSTM='"+code.substring(0,3)+"' and FForbidStatus = 'A' and FUseOrgId.FNumber = '"+deptData[1]+"'";
    userMap['FormId'] = 'BD_MATERIAL';
    userMap['FieldKeys'] =
    'FMATERIALID,FName,FNumber,FSpecification,FBaseUnitId.FName,FBaseUnitId.FNumber,FIsBatchManage,FCategoryID.FNumber';/*,SubHeadEntity1.FStoreUnitID.FNumber*/
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    materialDate = [];
    materialDate = jsonDecode(order);
    var scanCode = [materialDate[0][2],code.substring(3,9),"","","","N"];
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    if (materialDate.length > 0) {
      Map<String, dynamic> serialMap = Map();
      serialMap['FormId'] = 'BD_SerialMainFile';
      serialMap['FieldKeys'] = 'FStockStatus';
      serialMap['FilterString'] = "FNumber = '" +
          code.substring(9,15) +
          "' and FMaterialID.FNumber = '" + materialDate[0][2] + "'";
      Map<String, dynamic> serialDataMap = Map();
      serialDataMap['data'] = serialMap;
      String serialRes = await CurrencyEntity.polling(serialDataMap);
      var serialJson = jsonDecode(serialRes);
      if ((serialJson.length > 1 || (serialJson.length > 0 && serialJson[0][0] != "1"))) {// && materialDate[0][7] != '001'
        ToastUtil.showInfo('该序列号已出库或未入库');
        return;
      }
      var msg = "";
      var orderIndex = 0;
      for (var value in orderDate) {
        if(value[5] == materialDate[0][2]){
          msg = "";
          if(fNumber.lastIndexOf(materialDate[0][2])  == orderIndex){
            break;
          }
        }else{
          msg = '条码不在单据物料中';
        }
        orderIndex++;
      };
      if(msg !=  ""){
        ToastUtil.showInfo(msg);
        return;
      }
      var number = 0;
      var barcodeNum = '1';
      var hobbyIndex = 0;
      var residue = 1.0;
      for (var element in hobby) {
        hobbyIndex++;
        //判断是否启用批号
        if (element[5]['isHide']) {
          //不启用  && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                          double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item = fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              //判断扫描数量是否大于单据数量
              if (double.parse(element[3]['value']['label']) >=
                  element[9]['value']['label']) {
                continue;
              } else {
                //判断条码数量
                if ((double.parse(element[3]['value']['label']) + residue) >
                    0 &&
                    residue > 0) {
                  //判断条码是否重复
                  if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                    //判断末尾
                    if (fNumber.lastIndexOf(
                        element[0]['value']['value'].toString()) ==
                        (hobbyIndex - 1)) {
                      var item = fsn;
                      element[10]['value']['label'] = residue.toString();
                      element[10]['value']['value'] = residue.toString();
                      element[3]['value']['label'] =
                          (double.parse(element[3]['value']['label']) + residue)
                              .toString();
                      element[3]['value']['value'] =
                      element[3]['value']['label'];
                      residue = (residue * 100 -
                          double.parse(element[10]['value']['value']) *
                              100) /
                          100;
                      element[0]['value']['surplus'] =
                          (element[9]['value']['value'] * 100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                      element[0]['value']['kingDeeCode'].add(item);
                      element[0]['value']['scanCode'].add(code);
                    } else {
                      //判断剩余数量是否大于扫码数量
                      if (element[0]['value']['surplus'] >= residue) {
                        var item = fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                residue)
                                .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = 0.0;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        var item = fsn;
                        element[10]['value']['label'] =
                            element[0]['value']['surplus'].toString();
                        element[10]['value']['value'] =
                            element[0]['value']['surplus'].toString();
                        element[3]['value']['label'] = (element[0]['value']
                        ['surplus'] +
                            double.parse(element[3]['value']['label']))
                            .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = (residue * 100 -
                            double.parse(element[10]['value']['value']) *
                                100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        } else {
          //启用批号 && element[4]['value']['value'] == barCodeScan[6]
          if (element[0]['value']['value'] == scanCode[0]) {
            if (element[0]['value']['barcode'].indexOf(code) == -1) {
              if (scanCode.length > 4) {
                element[0]['value']['barcode'].add(code);
              }
              if (scanCode[5] == "N") {
                if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                  if (element[5]['value']['value'] == "") {
                    element[5]['value']['label'] = scanCode[1];
                    element[5]['value']['value'] = scanCode[1];
                  }
                  element[3]['value']['label'] =
                      (double.parse(element[3]['value']['label']) +
                          double.parse(barcodeNum))
                          .toString();
                  element[3]['value']['value'] = element[3]['value']['label'];
                  var item = fsn;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[0]['value']['scanCode'].add(code);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum =
                      (double.parse(barcodeNum) - double.parse(barcodeNum))
                          .toString();
                }
                break;
              }
              if (element[5]['value']['value'] == scanCode[1]) {
                //判断扫描数量是否大于单据数量
                if (double.parse(element[3]['value']['label']) >=
                    element[9]['value']['label']) {
                  continue;
                } else {
                  //判断条码数量
                  if ((double.parse(element[3]['value']['label']) + residue) >
                      0 &&
                      residue > 0) {
                    //判断条码是否重复
                    if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                      //判断末尾
                      if (fNumber.lastIndexOf(
                          element[0]['value']['value'].toString()) ==
                          (hobbyIndex - 1)) {
                        var item = fsn;
                        element[10]['value']['label'] = residue.toString();
                        element[10]['value']['value'] = residue.toString();
                        element[3]['value']['label'] =
                            (double.parse(element[3]['value']['label']) +
                                residue)
                                .toString();
                        element[3]['value']['value'] =
                        element[3]['value']['label'];
                        residue = (residue * 100 -
                            double.parse(element[10]['value']['value']) *
                                100) /
                            100;
                        element[0]['value']['surplus'] =
                            (element[9]['value']['value'] * 100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                        ;
                        element[0]['value']['kingDeeCode'].add(item);
                        element[0]['value']['scanCode'].add(code);
                      } else {
                        //判断剩余数量是否大于扫码数量
                        if (element[0]['value']['surplus'] >= residue) {
                          var item = fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                  residue)
                                  .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = 0.0;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          var item = fsn;
                          element[10]['value']['label'] =
                              element[0]['value']['surplus'].toString();
                          element[10]['value']['value'] =
                              element[0]['value']['surplus'].toString();
                          element[3]['value']['label'] = (element[0]['value']
                          ['surplus'] +
                              double.parse(element[3]['value']['label']))
                              .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = (residue * 100 -
                              double.parse(element[10]['value']['value']) *
                                  100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        }
                      }
                    }
                  }
                }
              } else {
                if (element[5]['value']['value'] == "") {
                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                  //判断扫描数量是否大于单据数量
                  if (double.parse(element[3]['value']['label']) >=
                      element[9]['value']['label']) {
                    continue;
                  } else {
                    //判断条码数量
                    if ((double.parse(element[3]['value']['label']) + residue) >
                        0 &&
                        residue > 0) {
                      //判断条码是否重复
                      if (element[0]['value']['scanCode'].indexOf(code) == -1) {
                        //判断末尾
                        if (fNumber.lastIndexOf(
                            element[0]['value']['value'].toString()) ==
                            (hobbyIndex - 1)) {
                          var item = fsn;
                          element[10]['value']['label'] = residue.toString();
                          element[10]['value']['value'] = residue.toString();
                          element[3]['value']['label'] =
                              (double.parse(element[3]['value']['label']) +
                                  residue)
                                  .toString();
                          element[3]['value']['value'] =
                          element[3]['value']['label'];
                          residue = (residue * 100 -
                              double.parse(element[10]['value']['value']) *
                                  100) /
                              100;
                          element[0]['value']['surplus'] = (element[9]['value']
                          ['value'] *
                              100 -
                              double.parse(element[3]['value']['label']) *
                                  100) /
                              100;
                          ;
                          element[0]['value']['kingDeeCode'].add(item);
                          element[0]['value']['scanCode'].add(code);
                        } else {
                          //判断剩余数量是否大于扫码数量
                          if (element[0]['value']['surplus'] >= residue) {
                            var item = fsn;
                            element[10]['value']['label'] = residue.toString();
                            element[10]['value']['value'] = residue.toString();
                            element[3]['value']['label'] =
                                (double.parse(element[3]['value']['label']) +
                                    residue)
                                    .toString();
                            element[3]['value']['value'] =
                            element[3]['value']['label'];
                            residue = 0.0;
                            element[0]['value']['surplus'] = (element[9]
                            ['value']['value'] *
                                100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          } else {
                            var item = fsn;
                            element[10]['value']['label'] =
                                element[0]['value']['surplus'].toString();
                            element[10]['value']['value'] =
                                element[0]['value']['surplus'].toString();
                            element[3]['value']['label'] = (element[0]['value']
                            ['surplus'] +
                                double.parse(element[3]['value']['label']))
                                .toString();
                            element[3]['value']['value'] =
                            element[3]['value']['label'];
                            residue = (residue * 100 -
                                double.parse(
                                    element[10]['value']['value']) *
                                    100) /
                                100;
                            element[0]['value']['surplus'] = (element[9]
                            ['value']['value'] *
                                100 -
                                double.parse(element[3]['value']['label']) *
                                    100) /
                                100;
                            ;
                            element[0]['value']['kingDeeCode'].add(item);
                            element[0]['value']['scanCode'].add(code);
                          }
                        }
                      }
                    }
                  }
                }
              }
            } else {
              ToastUtil.showInfo('该标签已扫描');
              break;
            }
          }
        }
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
  Widget _item(title, var data, selectData, hobby, {String? label, var stock}) {
    if (selectData == null) {
      selectData = "";
    }
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: ListTile(
            title: Text(title),
            onTap: () => data.length > 0
                ? _onClickItem(data, selectData, hobby,
                    label: label, stock: stock)
                : {ToastUtil.showInfo('无数据')},
            trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              MyText(selectData.toString() == "" ? '暂无' : selectData.toString(),
                  color: Colors.grey, rightpadding: 18),
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
              PartRefreshWidget(globalKey, () {
                //2、使用 创建一个widget
                return MyText(
                    (PicketUtil.strEmpty(selectData[model])
                        ? '暂无'
                        : selectData[model])!,
                    color: Colors.grey,
                    rightpadding: 18);
              }),
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
      // selectDate: PDuration(month: 2),
      minDate: PDuration(year: 2020, month: 2, day: 10),
      maxDate: PDuration(second: 22),
      selectDate: (FDate == '' || FDate == null
          ? PDuration(year: 2021, month: 2, day: 10)
          : PDuration.parse(DateTime.parse(FDate))),
      // minDate: PDuration(hour: 12, minute: 38, second: 3),
      // maxDate: PDuration(hour: 12, minute: 40, second: 36),
      onConfirm: (p) {
        print('longer >>> 返回数据：$p');
        setState(() {
          switch (model) {
            case DateMode.YMD:
              selectData[model] = formatDate(
                  DateFormat('yyyy-MM-dd')
                      .parse('${p.year}-${p.month}-${p.day}'),
                  [
                    yyyy,
                    "-",
                    mm,
                    "-",
                    dd,
                  ]);
              FDate = formatDate(
                  DateFormat('yyyy-MM-dd')
                      .parse('${p.year}-${p.month}-${p.day}'),
                  [
                    yyyy,
                    "-",
                    mm,
                    "-",
                    dd,
                  ]);
              break;
          }
        });
      },
      // onChanged: (p) => print(p),
    );
  }

  void _onClickItem(var data, var selectData, hobby,
      {String? label, var stock}) {
    Pickers.showSinglePicker(
      context,
      data: data,
      selectData: selectData,
      pickerStyle: DefaultPickerStyle(),
      suffix: label,
      onConfirm: (p) {
        print('longer >>> 返回数据：$p');
        print('longer >>> 返回数据类型：${p.runtimeType}');
        setState(() {
          if (hobby == 'customer') {
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
              }
              elementIndex++;
            });
          }
        });
      },
    );
  }

  List<Widget> _getHobby() {
    List<Widget> tempList = [];
    for (int i = 0; i < this.hobby.length; i++) {
      List<Widget> comList = [];
      for (int j = 0; j < this.hobby[i].length; j++) {
        if (!this.hobby[i][j]['isHide']) {
          /*if (j == 8 || j == 11) {
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
                            IconButton(
                              icon: new Icon(Icons.filter_center_focus),
                              tooltip: '点击扫描',
                              onPressed: () {
                                this._textNumber.text =
                                    this.hobby[i][j]["value"]["label"];
                                this._FNumber =
                                    this.hobby[i][j]["value"]["label"];
                                checkData = i;
                                checkDataChild = j;
                                scanDialog();
                                if (this.hobby[i][j]["value"]["label"] != 0) {
                                  this._textNumber.value =
                                      _textNumber.value.copyWith(
                                    text: this.hobby[i][j]["value"]["label"],
                                  );
                                }
                              },
                            ),
                          ])),
                ),
                divider,
              ]),
            );
          } else*/
          if (j == 4) {
            comList.add(
              _item('仓库:', stockList, this.hobby[i][j]['value']['label'],
                  this.hobby[i][j],
                  stock: this.hobby[i]),
            );
          } else if (j == 6) {
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
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: new Icon(Icons.filter_center_focus),
                                tooltip: '点击扫描',
                                onPressed: () {
                                  this._textNumber.text = this
                                      .hobby[i][j]["value"]["label"]
                                      .toString();
                                  this._FNumber = this
                                      .hobby[i][j]["value"]["label"]
                                      .toString();
                                  checkItem = 'FNumber';
                                  this.show = false;
                                  checkData = i;
                                  checkDataChild = j;
                                  scanDialog();
                                  print(this.hobby[i][j]["value"]["label"]);
                                  if (this.hobby[i][j]["value"]["label"] != 0) {
                                    this._textNumber.value =
                                        _textNumber.value.copyWith(
                                      text: this
                                          .hobby[i][j]["value"]["label"]
                                          .toString(),
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
                            new MaterialButton(
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
                      /* MyText(orderDate[i][j],
                        color: Colors.grey, rightpadding: 18),*/
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
                  /*  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('输入数量',
                        style: TextStyle(
                            fontSize: 16, decoration: TextDecoration.none)),
                  ),*/
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
                          // 关闭 Dialog
                          Navigator.pop(context);
                          setState(() {
                            this.hobby[checkData][checkDataChild]["value"]
                                ["label"] = _FNumber;
                            this.hobby[checkData][checkDataChild]['value']
                                ["value"] = _FNumber;
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

  pushDown(val, type) async {
    //下推
    Map<String, dynamic> pushMap = Map();
    pushMap['EntryIds'] = val;
    pushMap['RuleId'] = "DeliveryNotice-OutStock";
    pushMap['TargetFormId'] = "SAL_OUTSTOCK";
    pushMap['IsEnableDefaultRule'] = "false";
    pushMap['IsDraftWhenSaveFail'] = "false";
    var downData = await SubmitEntity.pushDown(
        {"formid": "SAL_DELIVERYNOTICE", "data": pushMap});
    var res = jsonDecode(downData);
    print(res);
    //判断成功
    if (res['Result']['ResponseStatus']['IsSuccess']) {
      //查询入库单
      var entitysNumber =
          res['Result']['ResponseStatus']['SuccessEntitys'][0]['Number'];
      Map<String, dynamic> inOrderMap = Map();
      inOrderMap['FormId'] = 'SAL_OUTSTOCK';
      inOrderMap['FilterString'] = "FBillNo='$entitysNumber'";
      inOrderMap['FieldKeys'] =
          'FEntity_FEntryId,FMaterialID.FNumber,FMaterialID.FName,FUnitID.FNumber';
      String order = await CurrencyEntity.polling({'data': inOrderMap});
      print(order);
      var resData = jsonDecode(order);
      //组装数据
      Map<String, dynamic> dataMap = Map();
      dataMap['data'] = inOrderMap;
      Map<String, dynamic> orderMap = Map();
      orderMap['NeedUpDataFields'] = [
        'FStockStatusId',
        'FRealQty',
        'FInStockType'
      ];
      orderMap['IsDeleteEntry'] = false;
      Map<String, dynamic> Model = Map();
      Model['FID'] = res['Result']['ResponseStatus']['SuccessEntitys'][0]['Id'];
      var FEntity = [];
      for (int entity = 0; entity < resData.length; entity++) {
        for (int element = 0; element < this.hobby.length; element++) {
          if (resData[entity][1].toString() ==
              this.hobby[element][0]['value']['value'].toString()) {
            Map<String, dynamic> FEntityItem = Map();
            FEntityItem['FEntryID'] = resData[entity][0];
            FEntityItem['FStockStatusId'] = {"FNumber": "KCZT01_SYS"};
            FEntityItem['FRealQty'] = this.hobby[element][3]['value']['value'];
            FEntityItem['FStockID'] = {
              "FNumber": this.hobby[element][4]['value']['value']
            };
            var fSerialSub = [];
            var kingDeeCode = this.hobby[element][0]['value']['kingDeeCode'];
            for (int subj = 0; subj < kingDeeCode.length; subj++) {
              Map<String, dynamic> subObj = Map();
              var itemCode = kingDeeCode[subj].split("-");
              if(itemCode.length>2){
                if(itemCode.length > 3){
                  subObj['FSerialNo'] = itemCode[2]+'-'+itemCode[3];
                }else{
                  subObj['FSerialNo'] = itemCode[2];
                }
              }
              fSerialSub.add(subObj);
            }
            FEntityItem['FSerialSubEntity'] = fSerialSub;
            FEntity.add(FEntityItem);
          }
        }
      }
      Model['FEntity'] = FEntity;
      orderMap['Model'] = Model;
      dataMap = {"formid": "SAL_OUTSTOCK", "data": orderMap, "isBool": true};
      print(jsonEncode(dataMap));
      //返回保存参数
      return dataMap;
    } else {
      Map<String, dynamic> errorMap = Map();
      errorMap = {
        "msg": res['Result']['ResponseStatus']['Errors'][0]['Message'],
        "isBool": false
      };
      return errorMap;
    }
  }

  //保存
  saveOrder() async {
    if (this.hobby.length > 0) {
      setState(() {
        this.isSubmit = true;
      });
      Map<String, dynamic> dataMap = Map();
      dataMap['formid'] = 'SAL_OUTSTOCK';
      Map<String, dynamic> orderMap = Map();
      orderMap['NeedUpDataFields'] = [
        'FEntity',
        'FSerialSubEntity',
        'FSerialNo', "FPrice", "FTaxPrice", "FEntryTaxRate"
      ];
      orderMap['NeedReturnFields'] = [
        'FEntity',
        'FSerialSubEntity',
        'FSerialNo'
      ];
      orderMap['IsDeleteEntry'] = true;
      Map<String, dynamic> Model = Map();
      Model['FID'] = 0;
      Model['FBillType'] = {"FNUMBER": "CKD01_SYS"};
      Model['FDate'] = FDate;
      Model['F_UYEP_TEXT'] = "PDA-";
      //获取登录信息
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      var menuData = sharedPreferences.getString('MenuPermissions');
      var deptData = jsonDecode(menuData)[0];
      if (this._remarkContent.text == '') {
        this.isSubmit = false;
        ToastUtil.showInfo('请输入快递单号');
        return;
      }
      //判断有源单 无源单
      if (this.isScanWork) {
        Model['FStockOrgId'] = {"FNumber": orderDate[0][8].toString()};
        Model['FSaleOrgId'] = {"FNumber": orderDate[0][1].toString()};
        Model['FCustomerID'] = {"FNumber": orderDate[0][16].toString()};
      } else {
        if (this.customerNumber == null) {
          this.isSubmit = false;
          ToastUtil.showInfo('请选择客户');
          return;
        }
        Model['FStockOrgId'] = {"FNumber": this.fOrgID};
        Model['FSaleOrgId'] = {"FNumber": this.fOrgID};
        Model['FCustomerID'] = {"FNumber": this.customerNumber};
      }
      Model['FCarriageNO'] = this._remarkContent.text;
      Model['F_UYEP_UserId'] ={"FUserID": orderDate[0][29]};
      Model['F_UYEP_Date'] = orderDate[0][31];
      Model['FNote'] = orderDate[0][33];
      Model['FReceiverContactID'] ={"FNAME": orderDate[0][26]};
      Model['FReceiveAddress'] = orderDate[0][27];
      Model['FLinkPhone'] = orderDate[0][28];
      var FEntity = [];
      var hobbyIndex = 0;
      this.hobby.forEach((element) {
        if (element[3]['value']['value'] != '0' &&
            element[4]['value']['value'] != '') {
          Map<String, dynamic> FEntityItem = Map();
          FEntityItem['FMaterialId'] = {
            "FNumber": element[0]['value']['value']
          };

          FEntityItem['FUnitID'] = {"FNumber": element[2]['value']['value']};
          FEntityItem['FReturnType'] = 1;
          FEntityItem['FLot'] = {"FNumber": element[5]['value']['value']};
          FEntityItem['FStockID'] = {"FNumber": element[4]['value']['value']};
          FEntityItem['FStockLocId'] = {
            "FSTOCKLOCID__FF100011": {"FNumber": element[6]['value']['value']}
          };
          FEntityItem['FRealQty'] = element[3]['value']['value'];
          FEntityItem['FSrcBillNo'] = this.FBillNo;
          FEntityItem['FSoorDerno'] = orderDate[hobbyIndex][30];
          FEntityItem['F_UYEP_Text1'] = orderDate[hobbyIndex][32];
          FEntityItem['FEntrynote'] = orderDate[hobbyIndex][34];
          FEntityItem['FPrice'] = orderDate[hobbyIndex][35];
          FEntityItem['FTaxPrice'] = orderDate[hobbyIndex][23];
          FEntityItem['FEntryTaxRate'] = orderDate[hobbyIndex][24];
          FEntityItem['FEntity_Link'] = [
            {
              "FEntity_Link_FRuleId": "DeliveryNotice-OutStock",
              "FEntity_Link_FSTableName": "T_SAL_DELIVERYNOTICEENTRY",
              "FEntity_Link_FSBillId": orderDate[hobbyIndex][15],
              "FEntity_Link_FSId": orderDate[hobbyIndex][4],
              "FEntity_Link_FSALBASEQTY": element[3]['value']['value']
            }
          ];
          var fSerialSub = [];
          var kingDeeCode = element[0]['value']['kingDeeCode'];
          for (int subj = 0; subj < kingDeeCode.length; subj++) {
            Map<String, dynamic> subObj = Map();
            if (kingDeeCode[subj].split("-").length > 2) {
              var itemCode = kingDeeCode[subj].split("-");
              if(itemCode.length>2){
                if(itemCode.length > 3){
                  subObj['FSerialNo'] = itemCode[2]+'-'+itemCode[3];
                }else{
                  subObj['FSerialNo'] = itemCode[2];
                }
              }
            } else {
              subObj['FSerialNo'] = kingDeeCode[subj];
            }
            fSerialSub.add(subObj);
          }
          FEntityItem['FSerialSubEntity'] = fSerialSub;
          FEntity.add(FEntityItem);
        }
        hobbyIndex++;
      });
      if (FEntity.length == 0) {
        this.isSubmit = false;
        ToastUtil.showInfo('请输入数量,仓库');
        return;
      }
      Model['FEntity'] = FEntity;
      orderMap['Model'] = Model;
      dataMap['data'] = orderMap;
      print(jsonEncode(dataMap));
      var paramsvalve=jsonEncode(dataMap);
      String order = await SubmitEntity.save(dataMap);
      var res = jsonDecode(order);
      print(res);
      if (res['Result']['ResponseStatus']['IsSuccess']) {
        Map<String, dynamic> submitMap = Map();
        submitMap = {
          "formid": "SAL_OUTSTOCK",
          "data": {
            'Ids': res['Result']['ResponseStatus']['SuccessEntitys'][0]['Id']
          }
        };
        //提交
        HandlerOrder.orderHandler(
            context,
            submitMap,
            1,
            "PUR_ReceiveBill",
            SubmitEntity.submit(submitMap))
            .then((submitResult) async {
          if (submitResult) {
            var errorMsg = "";
            if (fBarCodeList == 1) {
              for (int i = 0; i < this.hobby.length; i++) {
                if (this.hobby[i][3]['value']['value'] != '0'&&
                    this.hobby[i][4]['value']['value'] != '') {
                  var kingDeeCode = this.hobby[i][0]['value']['kingDeeCode'];
                  for (int j = 0; j < kingDeeCode.length; j++) {
                    Map<String, dynamic> dataCodeMap = Map();
                    dataCodeMap['formid'] = 'QDEP_Cust_BarCodeList';
                    Map<String, dynamic> orderCodeMap = Map();
                    orderCodeMap['NeedReturnFields'] = [];
                    orderCodeMap['IsDeleteEntry'] = false;
                    Map<String, dynamic> codeModel = Map();
                    var itemCode = kingDeeCode[j].split("-");
                    if(itemCode.length>1){

                      codeModel['FID'] = itemCode[0];
                      Map<String, dynamic> codeFEntityItem = Map();
                      codeFEntityItem['FBillDate'] = FDate;
                      codeFEntityItem['FOutQty'] = itemCode[1];
                      codeFEntityItem['FEntryBillNo'] = orderDate[i][0];
                      codeFEntityItem['FEntryStockID'] = {
                        "FNUMBER": this.hobby[i][4]['value']['value']
                      };
                      var codeFEntity = [codeFEntityItem];
                      codeModel['FEntity'] = codeFEntity;
                      orderCodeMap['Model'] = codeModel;
                      dataCodeMap['data'] = orderCodeMap;
                      String codeRes = await SubmitEntity.save(dataCodeMap);
                      var barcodeRes = jsonDecode(codeRes);
                      if (!barcodeRes['Result']['ResponseStatus']['IsSuccess']) {
                        errorMsg += "错误反馈：" +
                            itemCode[1] +
                            ":" +
                            barcodeRes['Result']['ResponseStatus']['Errors'][0]
                            ['Message'];
                      }
                      print(codeRes);
                    }
                  }

                }
              }
            }
            if (errorMsg != "") {
              ToastUtil.errorDialog(context, errorMsg);
              this.isSubmit = false;
            }
            //提交清空页面
            setState(() {
              this.hobby = [];
              this.orderDate = [];
              this.FBillNo = '';
              ToastUtil.showInfo('提交成功');
              Navigator.of(context).pop("refresh");
            });
          } else {
            this.isSubmit = false;
          }
        });

        /* setState(() {
          this.isSubmit = true;
        });
        var hobbyIndex = 0;
        var EntryIds = '';
        this.hobby.forEach((element) {
          if (double.parse(element[3]['value']['value']) > 0) {
            if (EntryIds == '') {
              EntryIds = orderDate[hobbyIndex][4].toString();
            } else {
              EntryIds = EntryIds + ',' + orderDate[hobbyIndex][4].toString();
            }
          }
          hobbyIndex++;
        });
        var resCheck = await this.pushDown(EntryIds, '');
        if (resCheck['isBool'] != false) {
          print(resCheck);
          Map<String, dynamic> submitMap = Map();
          submitMap = {
            "formid": "SAL_OUTSTOCK",
            "data": {
              'Ids': resCheck['data']['Model']['FID']
            }
          };*/
        //提交
        /* HandlerOrder.orderHandler(context, submitMap, 1, "SAL_OUTSTOCK",
                SubmitEntity.submit(submitMap))
            .then((submitResult) {
          if (submitResult) {
            //审核
            HandlerOrder.orderHandler(context, submitMap, 1, "SAL_OUTSTOCK",
                    SubmitEntity.audit(submitMap))
                .then((auditResult) async{
              if (auditResult) {
                var errorMsg = "";
                if(fBarCodeList == 1){
                  for (int i = 0; i < this.hobby.length; i++) {
                    if (this.hobby[i][3]['value']['value'] != '0') {
                      var kingDeeCode = this.hobby[i][0]['value']['kingDeeCode'];
                      for(int j = 0;j<kingDeeCode.length;j++){
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
                        codeFEntityItem['FEntryBillNo'] = orderDate[i][0];
                        codeFEntityItem['FEntryStockID'] ={
                          "FNUMBER": this.hobby[i][4]['value']['value']
                        };
                        var codeFEntity = [codeFEntityItem];
                        codeModel['FEntity'] = codeFEntity;
                        orderCodeMap['Model'] = codeModel;
                        dataCodeMap['data'] = orderCodeMap;
                        String codeRes = await SubmitEntity.save(dataCodeMap);
                        var barcodeRes = jsonDecode(codeRes);
                        if(!barcodeRes['Result']['ResponseStatus']['IsSuccess']){
                          errorMsg +="错误反馈："+itemCode[1]+":"+barcodeRes['Result']['ResponseStatus']['Errors'][0]['Message'];
                        }
                        print(codeRes);
                      }
                    }
                  }
                }
                if(errorMsg !=""){
                  ToastUtil.errorDialog(context,
                      errorMsg);
                  this.isSubmit = false;
                }
                //提交清空页面
                setState(() {
                  this.hobby = [];
                  this.orderDate = [];
                  this.FBillNo = '';
                  ToastUtil.showInfo('提交成功');
                  Navigator.of(context).pop("refresh");
                });
              } else {
                //失败后反审
                HandlerOrder.orderHandler(context, submitMap, 0, "SAL_OUTSTOCK",
                        SubmitEntity.unAudit(submitMap))
                    .then((unAuditResult) {
                  if (unAuditResult) {
                    this.isSubmit = false;
                  }else{
                    this.isSubmit = false;
                  }
                });
              }
            });
          } else {
            this.isSubmit = false;
          }
        });*/
      } else {
        setState(() {
          this.isSubmit = false;
          ToastUtil.errorDialog(
              context, res['Result']['ResponseStatus']['Errors'][0]['Message']);
        });
      }
    } else {
      ToastUtil.showInfo('无提交数据');
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

//扫码函数,最简单的那种
  Future scan() async {
    String cameraScanResult = await scanner.scan(); //通过扫码获取二维码中的数据
    getScan(cameraScanResult); //将获取到的参数通过HTTP请求发送到服务器
    print(cameraScanResult); //在控制台打印
  }

//用于验证数据(也可以在控制台直接打印，但模拟器体验不好)
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
            title: Text("销售出库"),
            centerTitle: true,
            leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop("refresh");
                }),
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
                            /* title: TextWidget(FBillNoKey, '生产订单：'),*/
                            title: Text("客户：$cusName"),
                          ),
                        ),
                        divider,
                      ],
                    ),
                  ),
                  /* _dateItem('日期：', DateMode.YMD),*/
                  Visibility(
                    maintainSize: false,
                    maintainState: false,
                    maintainAnimation: false,
                    visible: !isScanWork,
                    child: _item('客户:', this.customerList, this.customerName,
                        'customer'),
                  ),
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: Text("收件人：$FLinkMan"),
                        ),
                      ),
                      divider,
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: Text("收件电话：$FLinkPhone"),
                        ),
                      ),
                      divider,
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: Text("收件地址：$FHeadLocId"),
                        ),
                      ),
                      divider,
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListTile(
                          title: TextField(
                            //最多输入行数
                            maxLines: 1,
                            decoration: InputDecoration(
                              hintText: "快递单号",
                              //给文本框加边框
                              border: OutlineInputBorder(),
                            ),
                            controller: this._remarkContent,
                            //改变回调
                            onChanged: (value) {
                              setState(() {
                                _remarkContent.value = TextEditingValue(
                                    text: value,
                                    selection: TextSelection.fromPosition(
                                        TextPosition(
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
                        color: this.isSubmit
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                        textColor: Colors.white,
                        onPressed: () async =>
                            this.isSubmit ? null : _showSumbitDialog(),
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
