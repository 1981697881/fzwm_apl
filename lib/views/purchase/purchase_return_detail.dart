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

final String _fontFamily = Platform.isWindows ? "Roboto" : "";

class PurchaseReturnDetail extends StatefulWidget {
  var FBillNo;

  PurchaseReturnDetail({Key ?key, @required this.FBillNo}) : super(key: key);

  @override
  _ReturnGoodsDetailState createState() => _ReturnGoodsDetailState(FBillNo);
}

class _ReturnGoodsDetailState extends State<PurchaseReturnDetail> {
  var _remarkContent = new TextEditingController();
  var _FVBMYContent = new TextEditingController();
  GlobalKey<PartRefreshWidgetState> globalKey = GlobalKey();

  final _textNumber = TextEditingController();
  var checkItem;
  String FBillNo = '';
  String FSaleOrderNo = '';
  String FName = '';
  String FNumber = '';
  String supName = '';
  String FDate = '';
  var supplierName;
  var supplierNumber;
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
  var supplierList = [];
  List<dynamic> supplierListObj = [];
  var stockList = [];
  List<dynamic> stockListObj = [];
  List<dynamic> orderDate = [];
  List<dynamic> materialDate = [];
  final divider = Divider(height: 1, indent: 20);
  final rightIcon = Icon(Icons.keyboard_arrow_right);
  final scanIcon = Icon(Icons.filter_center_focus);
  static const scannerPlugin =
  const EventChannel('com.shinow.pda_scanner/plugin');
  StreamSubscription ?_subscription;
  var _code;
  var _FNumber;
  var fBillNo;
  var fBarCodeList;
  _ReturnGoodsDetailState(FBillNo) {
    if (FBillNo != null) {
      this.fBillNo = FBillNo['value'];
      this.getOrderList();
      isScanWork = true;
    } else {
      isScanWork = false;
      this.fBillNo = '';
      getSupplierList();
      getStockList();
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
    /*getWorkShop();*/

  }
  //获取线路名称
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
  //获取供应商
  getSupplierList() async {
    Map<String, dynamic> userMap = Map();
    userMap['FormId'] = 'BD_Supplier';
    userMap['FieldKeys'] = 'FSupplierId,FName,FNumber';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String res = await CurrencyEntity.polling(dataMap);
    supplierListObj = jsonDecode(res);
    supplierListObj.forEach((element) {
      supplierList.add(element[1]);
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
    if(fOrgID == null){
      this.fOrgID = deptData[1];
    }
    userMap['FilterString'] = "FForbidStatus = 'A' and FUseOrgId.FNumber='"+fOrgID+"'";
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
    Map<String, dynamic> userMap = Map();
    print(fBillNo);
    userMap['FilterString'] = "fBillNo='$fBillNo'";
    userMap['FormId'] = 'PUR_MRAPP';
    userMap['OrderString'] = 'FMaterialId.FNumber ASC';
    userMap['FieldKeys'] =
    'FBillNo,FPURCHASEORGID.FNumber,FPURCHASEORGID.FName,FDate,FEntity_FEntryId,FMATERIALID.FNumber,FMATERIALID.FName,FMATERIALID.FSpecification,FAPPORGID.FNumber,FAPPORGID.FName,FUNITID.FNumber,FUNITID.FName,FMRAPPQTY,FAPPROVEDATE,FMRQTY,FID,FSUPPLIERID.FNumber,FSUPPLIERID.FName,FStockID.FName,FStockID.FNumber,FLot.FNumber,FStockID.FIsOpenLocation,FMATERIALID.FIsBatchManage,FPRICEUNITID_F.FNumber,FAPPROVEPRICE_F,FEntryTaxRate,FBASEUNITID.FName,FBASEUNITID.FNumber,FRequireOrgId.FNumber';
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    orderDate = [];
    orderDate = jsonDecode(order);
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    if (orderDate.length > 0) {
      this.FBillNo = orderDate[0][0];
      this.fOrgID = orderDate[0][8];
      this.supName = orderDate[0][17];
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
          "isHide": false,
          "name": "FMaterialIdFSpecification",
          "value": {"label": value[7], "value": value[7]}
        });
        arr.add({
          "title": "单位名称",
          "name": "FUnitId",
          "isHide": false,
          "value": {"label": value[26], "value": value[27]}
        });
        arr.add({
          "title": "实退数量",
          "name": "FRealQty",
          "isHide": false,/*value[12]*/
          "value": {"label": "0", "value": "0"}
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
        "isHide": value[22] != true,
        "value": {"label": "", "value": ""}
        });
        arr.add({
        "title": "仓位",
        "name": "FStockLocID",
        "isHide": false,
        "value": {"label": "", "value": "","hide": value[21]}
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
          "title": "可退数量",
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

  void _onEvent(event) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var deptData = sharedPreferences.getString('menuList');
    var menuList = new Map<dynamic, dynamic>.from(jsonDecode(deptData));
    fBarCodeList = menuList['FBarCodeList'];
    /*if (fBarCodeList == 1) {*/
    Map<String, dynamic> barcodeMap = Map();
    barcodeMap['FilterString'] = "FBarCodeEn='" + event + "'";
    barcodeMap['FormId'] = 'QDEP_Cust_BarCodeList';
    barcodeMap['FieldKeys'] =
    'FID,FInQtyTotal,FOutQtyTotal,FEntity_FEntryId,FRemainQty,FBarCodeQty,FEntryStockID.FName,FEntryStockID.FNumber,FMATERIALID.FNUMBER,FOwnerID.FNumber,FBarCode';
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
        this.getMaterialList(barcodeData, barcodeData[0][10]);
        print("ChannelPage: $event");
      }else{
        ToastUtil.showInfo(msg);
      }
    } else {
      ToastUtil.showInfo('条码不在条码清单中');
    }
    /*} else {
      _code = event;
      this.getMaterialList("", _code);
      print("ChannelPage: $event");
    }*/
    print("ChannelPage: $event");
  }

  void _onError(Object error) {
    setState(() {
      _code = "扫描异常";
    });
  }
  getMaterialList(barcodeData,code) async {
    Map<String, dynamic> userMap = Map();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var menuData = sharedPreferences.getString('MenuPermissions');
    var deptData = jsonDecode(menuData)[0];
    var scanCode = code.split(";");
    userMap['FilterString'] = "FNumber='"+barcodeData[0][8]+"' and FForbidStatus = 'A' and FUseOrgId.FNumber = '"+deptData[1]+"'";
    userMap['FormId'] = 'BD_MATERIAL';
    userMap['FieldKeys'] =
    'FMATERIALID,FName,FNumber,FSpecification,FBaseUnitId.FName,FBaseUnitId.FNumber,FIsBatchManage';/*,SubHeadEntity1.FStoreUnitID.FNumber*/
    Map<String, dynamic> dataMap = Map();
    dataMap['data'] = userMap;
    String order = await CurrencyEntity.polling(dataMap);
    materialDate = [];
    materialDate = jsonDecode(order);
    FDate = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    selectData[DateMode.YMD] = formatDate(DateTime.now(), [yyyy, "-", mm, "-", dd,]);
    if (materialDate.length > 0) {
      var barCodeScan;
      if(fBarCodeList == 1){
        barCodeScan = barcodeData[0];
        barCodeScan[3] = barCodeScan[3].toString();
      }else{
        barCodeScan = scanCode;
      }
      var barcodeNum = scanCode[3];
      for (var element in hobby) {
        var residue = 0.0;
        //判断是否启用批号
        if(element[5]['isHide']){//不启用
          if(element[0]['value']['value'] == scanCode[0]){
            if(element[0]['value']['barcode'].indexOf(code) == -1){
              //判断是否可重复扫码
              if(scanCode.length>4){
                element[0]['value']['barcode'].add(code);
              }
              if(scanCode[5] == "N" ){
                  element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                  element[3]['value']['value']=element[3]['value']['label'];
                  var item = barCodeScan[0].toString()+"-"+barcodeNum;
                  element[0]['value']['kingDeeCode'].add(item);
                  element[10]['value']['label'] = barcodeNum.toString();
                  element[10]['value']['value'] = barcodeNum.toString();
                  barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                break;
              }
              //判断扫描数量是否大于单据数量
              if(double.parse(element[3]['value']['label']) >= element[9]['value']['value']) {
                  continue;
              }else {
                if((double.parse(element[3]['value']['label'])+double.parse(scanCode[4])) >= element[9]['value']['value']){
                  //判断条码是否重复
                  if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                    var item = barCodeScan[0].toString()+"-"+(element[9]['value']['value'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString();
                    element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                    element[3]['value']['value']=element[3]['value']['label'];
                    residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                    element[0]['value']['kingDeeCode'].add(item);
                  }else{
                    //获取已存在下标
                    var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                    element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                    element[3]['value']['value']=element[3]['value']['label'];
                    residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                    element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                  }
                }else{//数量不超出
                  //判断条码是否重复
                  if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                    element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                    element[3]['value']['value']=element[3]['value']['label'];
                    var item = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                    element[0]['value']['kingDeeCode'].add(item);
                  }else{
                    //获取已存在下标
                    var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                    element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                    element[3]['value']['value']=element[3]['value']['label'];
                    element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                  }
                  break;
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
              //判断是否可重复扫码
              if(scanCode.length>4){
                element[0]['value']['barcode'].add(code);
              }
              if(scanCode[5] == "N" ){
                if(element[5]['value']['value'] == "") {
                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                }
                element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(barcodeNum)).toString();
                element[3]['value']['value']=element[3]['value']['label'];
                var item = barCodeScan[0].toString()+"-"+barcodeNum;
                element[0]['value']['kingDeeCode'].add(item);
                element[10]['value']['label'] = barcodeNum.toString();
                element[10]['value']['value'] = barcodeNum.toString();
                barcodeNum = (double.parse(barcodeNum) - double.parse(barcodeNum)).toString();
                break;
              }
              if(element[5]['value']['value'] == scanCode[1]){

                //判断扫描数量是否大于单据数量
                if(double.parse(element[3]['value']['label']) >= element[9]['value']['value']) {
                    continue;
                }else {
                  if((double.parse(element[3]['value']['label'])+double.parse(scanCode[4])) >= element[9]['value']['value']){
                    //判断条码是否重复
                    if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                      var item = barCodeScan[0].toString()+"-"+(element[9]['value']['value'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString();
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                      element[0]['value']['kingDeeCode'].add(item);
                    }else{
                      //获取已存在下标
                      var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                      element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                    }
                  }else{//数量不超出
                    //判断条码是否重复
                    if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      var item = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                      element[0]['value']['kingDeeCode'].add(item);
                    }else{
                      //获取已存在下标
                      var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                      element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                      element[3]['value']['value']=element[3]['value']['label'];
                      element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                    }
                    break;
                  }
                }
              }else{
                if(element[5]['value']['value'] == ""){
                  element[5]['value']['label'] = scanCode[1];
                  element[5]['value']['value'] = scanCode[1];
                  //判断扫描数量是否大于单据数量
                  if(double.parse(element[3]['value']['label']) >= element[9]['value']['value']) {
                      continue;
                  }else {
                    if((double.parse(element[3]['value']['label'])+double.parse(scanCode[4])) >= element[9]['value']['value']){
                      //判断条码是否重复
                      if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                        var item = barCodeScan[0].toString()+"-"+(element[9]['value']['value'] - double.parse(element[3]['value']['label'])).toStringAsFixed(2).toString();
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                        element[0]['value']['kingDeeCode'].add(item);
                      }else{
                        //获取已存在下标
                        var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+(element[9]['value']['value'] - double.parse(element[3]['value']['label']))).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        residue = (element[9]['value']['value']*100 - double.parse(element[3]['value']['label'])*100)/100;;
                        element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                      }
                    }else{//数量不超出
                      //判断条码是否重复
                      if(element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']) == -1){
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        var item = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                        element[0]['value']['kingDeeCode'].add(item);
                      }else{
                        //获取已存在下标
                        var index = element[0]['value']['kingDeeCode'].indexOf(barCodeScan[0].toString()+"-"+element[3]['value']['value']);
                        element[3]['value']['label']=(double.parse(element[3]['value']['label'])+double.parse(scanCode[4])).toString();
                        element[3]['value']['value']=element[3]['value']['label'];
                        element[0]['value']['kingDeeCode'][index] = barCodeScan[0].toString()+"-"+element[3]['value']['value'];
                      }
                      break;
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
      setState(() {
        EasyLoading.dismiss();
      });
    } else {
      setState(() {
        EasyLoading.dismiss();
      });
      ToastUtil.showInfo('无数据');
    }
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
              MyText(selectData.toString()=="" ? '暂无':selectData.toString(),
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
              /*PartRefreshWidget(globalKey, () {*/
              //2、使用 创建一个widget
              /*return*/ MyText(
                  (PicketUtil.strEmpty(selectData[model])
                      ? '暂无'
                      : selectData[model])!,
                  color: Colors.grey,
                  rightpadding: 18),
              /* }),*/
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
              Map<String, dynamic> userMap = Map();
              selectData[model] = formatDate(DateFormat('yyyy-MM-dd').parse('${p.year}-${p.month}-${p.day}'), [yyyy, "-", mm, "-", dd,]);
              FDate = formatDate(DateFormat('yyyy-MM-dd').parse('${p.year}-${p.month}-${p.day}'), [yyyy, "-", mm, "-", dd,]);
              break;
          }
        });
      },
      // onChanged: (p) => print(p),
    );
  }

  void _onClickItem(var data, var selectData, hobby, {String ?label,var stock}) {
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
          if(hobby  == 'supplier'){
            supplierName = p;
            var elementIndex = 0;
            data.forEach((element) {
              if (element == p) {
                supplierNumber = supplierListObj[elementIndex][2];
              }
              elementIndex++;
            });
          } else{
            setState(() {
              hobby['value']['label'] = p;
            });
            var elementIndex = 0;
            data.forEach((element) {
              if (element == p) {
                hobby['value']['value'] = stockListObj[elementIndex][2];
              }
              elementIndex++;
            });
          }
        });
      },
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      new MaterialPageRoute(
        builder: (context) {
          return new Scaffold(
            appBar: new AppBar(
              title: new Text('系统设置'),
              centerTitle: true,
              leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: (){
                Navigator.of(context).pop("refresh");
              }),
            ),
            body: new ListView(padding: EdgeInsets.all(10), children: <Widget>[
              /* ListTile(
                leading: Icon(Icons.search),
                title: Text('版本信息'),
              ),
              Divider(
                height: 10.0,
                indent: 0.0,
                color: Colors.grey,
              ),*/
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('退出登录'),
                onTap: () async {
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  prefs.clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return LoginPage();
                      },
                    ),
                  );
                },
              ),
              Divider(
                height: 10.0,
                indent: 0.0,
                color: Colors.grey,
              ),
            ]),
          );
        },
      ),
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
          } else*/ if (j == 6) {
            comList.add(
              _item('仓库:', stockList, this.hobby[i][j]['value']['label'],
                  this.hobby[i][j],stock:this.hobby[i]),
            );
          }else if (j == 7) {
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
  //保存
  saveOrder() async {
    if (this.hobby.length > 0) {
      setState(() {
        this.isSubmit = true;
      });
      Map<String, dynamic> dataMap = Map();
      dataMap['formid'] = 'PUR_MRB';
      Map<String, dynamic> orderMap = Map();
      orderMap['NeedReturnFields'] = [];
      orderMap['IsDeleteEntry'] = false;
      Map<String, dynamic> Model = Map();
      Model['FID'] = 0;
      Model['FBillTypeID'] = {"FNUMBER": "TLD01_SYS"};
      Model['FDate'] = FDate;
      Model['FOwnerTypeIdHead'] = "BD_OwnerOrg";
      Model['FMRTYPE'] = "B";
      Model['FMRMODE'] = "A";
      Model['FOwnerIdHead'] = {"FNumber": this.fOrgID};
      //获取登录信息
      SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
      var menuData = sharedPreferences.getString('MenuPermissions');
      var deptData = jsonDecode(menuData)[0];
      //判断有源单 无源单
      if(this.isScanWork){
        Model['FStockOrgId'] = {"FNumber": orderDate[0][8].toString()};
        Model['FPurchaseOrgId'] = {"FNumber": orderDate[0][1].toString()};
        Model['FSupplierID'] = {"FNumber": orderDate[0][16].toString()};
      }else{
        if (this.supplierNumber == null) {
          this.isSubmit = false;
          ToastUtil.showInfo('请选择供应商');
          return;
        }
        Model['FStockOrgId'] = {"FNumber": this.fOrgID};
        Model['FPurchaseOrgId'] = {"FNumber": this.fOrgID};
        Model['FSupplierID'] = {"FNumber": this.supplierNumber};
      }
      var FEntity = [];
      var hobbyIndex = 0;
      this.hobby.forEach((element) {
        if (element[3]['value']['value'] != '0' &&
            element[4]['value']['value'] != '') {
          Map<String, dynamic> FEntityItem = Map();
          FEntityItem['FMaterialId'] = {"FNumber": element[0]['value']['value']};
          FEntityItem['FUnitID'] = {"FNumber": element[2]['value']['value']};
          FEntityItem['FSTOCKID'] = {"FNumber": element[4]['value']['value']};
          FEntityItem['FLot'] = {"FNumber": element[5]['value']['value']};
          FEntityItem['FSTOCKLOCID'] = {
            "FSTOCKLOCID__FF100011": {
              "FNumber": element[6]['value']['value']
            }
          };
          FEntityItem['FRMREALQTY'] = element[3]['value']['value'];
          FEntityItem['FOWNERTYPEID'] = "BD_OwnerOrg";
          FEntityItem['FOWNERID'] = {"FNumber": this.fOrgID};
          FEntityItem['FPRICEUNITID'] = {"FNumber": orderDate[hobbyIndex][23]};
          FEntityItem['FTAXPRICE'] = orderDate[hobbyIndex][24];
          FEntityItem['FENTRYTAXRATE'] = orderDate[hobbyIndex][25];
          /*FEntityItem['FEntity_Link'] = [
            {
              "FEntity_Link_FRuleId": "SalReturnNotice-SalReturnStock",
              "FEntity_Link_FSTableName": "T_SAL_RETURNNOTICEENTRY",
              "FEntity_Link_FSBillId": orderDate[hobbyIndex][15],
              "FEntity_Link_FSId": orderDate[hobbyIndex][4],
              "FEntity_Link_FSalBaseQty": element[8]['value']['value']
            }
          ];*/
          FEntity.add(FEntityItem);
        }
        hobbyIndex++;
      });
      if(FEntity.length==0){
        this.isSubmit = false;
        ToastUtil.showInfo('请输入数量,仓库');
        return;
      }
      Model['FPURMRBENTRY'] = FEntity;
      orderMap['Model'] = Model;
      dataMap['data'] = orderMap;
      print(jsonEncode(dataMap));
      String order = await SubmitEntity.save(dataMap);
      var res = jsonDecode(order);
      print(res);
      if (res['Result']['ResponseStatus']['IsSuccess']) {
        Map<String, dynamic> submitMap = Map();
        submitMap = {
          "formid": "PUR_MRB",
          "data": {
            'Ids': res['Result']['ResponseStatus']['SuccessEntitys'][0]['Id']
          }
        };
        //提交
        HandlerOrder.orderHandler(context,submitMap,1,"PUR_MRB",SubmitEntity.submit(submitMap)).then((submitResult) {
          if(submitResult){
            //审核
            HandlerOrder.orderHandler(context,submitMap,1,"PUR_MRB",SubmitEntity.audit(submitMap)).then((auditResult) {
              if(auditResult){
                //提交清空页面
                setState(() {
                  this.hobby = [];
                  this.orderDate = [];
                  this.FBillNo = '';
                  ToastUtil.showInfo('提交成功');
                  Navigator.of(context).pop("refresh");
                });
              }else{
                //失败后反审
                HandlerOrder.orderHandler(context,submitMap,0,"PUR_MRB",SubmitEntity.unAudit(submitMap)).then((unAuditResult) {
                  if(unAuditResult){
                    this.isSubmit = false;
                  }else{
                    this.isSubmit = false;
                  }
                });
              }
            });
          }else{
            this.isSubmit = false;
          }
        });
      } else {
        setState(() {
          this.isSubmit = false;
          ToastUtil.errorDialog(context,
              res['Result']['ResponseStatus']['Errors'][0]['Message']);
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
  @override
  Widget build(BuildContext context) {
    return FlutterEasyLoading(
      child: Scaffold(
          appBar: AppBar(
            title: Text("采购退货"),
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
                          /* title: TextWidget(FBillNoKey, '生产订单：'),*/
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
                            title: Text("供应商：$supName"),
                          ),
                        ),
                        divider,
                      ],
                    ),
                  ),
                  _dateItem('日期：', DateMode.YMD),
                  Visibility(
                    maintainSize: false,
                    maintainState: false,
                    maintainAnimation: false,
                    visible: !isScanWork,
                    child: _item('供应商:', this.supplierList, this.supplierName,
                        'supplier'),
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
                              hintText: "备注",
                              //给文本框加边框
                              border: OutlineInputBorder(),
                            ),
                            controller: this._remarkContent,
                            //改变回调
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
