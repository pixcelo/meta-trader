#property copyright "Copyright 2022, ttt."
#property link      ""
#property version   "1.00"
     
input int RCI_KIKAN1 = 9;
input int RCI_KIKAN2 = 26;
input int RCI_KIKAN3 = 52;
input int RCI_VIEW_CNT = 3;
input int RCI_KAI = -65;
input int RCI_URI = 80;
 
input int A_SPREAD = 100;
input double Lots = 1;
 
input int SL = 180;
input int TP = 210;
     
 
datetime prevtime;

int init()
  {

   return(INIT_SUCCEEDED);
  }
         
int start()
{
   int orderPtn = 0; //0:何もしない 1:買い 2:売り
   int total = 0;
            
   double ea_order_stop_price = 0, ea_order_good_price = 0; //ストップロスレート,利確レート,エントリーレート
   bool OrderKekka;
        
   // 新しい足ができた時だけやる
   if (Time[0] != prevtime)
   {
      prevtime = Time[0];
   }
   else
   {
      return(0);
   }
         
//***売買判断箇所***//
     
   // クロス確認  
   orderPtn = getRciSign(1,0);


//***売買判断箇所***//
     
   total = OrdersTotal();
   
   if (total == 0 && orderPtn > 0)   
   {
      if (orderPtn == 1) 
      {
         ea_order_stop_price = Ask - SL * Point;
         ea_order_good_price = Ask + TP * Point;     
      }
      else if (orderPtn == 2)
      {
         ea_order_stop_price = Bid + SL * Point;  
         ea_order_good_price = Bid - TP * Point;  
      }   
        
      // 新規注文
      OrderKekka = funcOrder_Send(orderPtn - 1, ea_order_stop_price, ea_order_good_price, 0, 777);
   }
           
   return(0);
}
        
//+------------------------------------------------------------------+
//|【関数】新規注文関数                                              |
//|                                                                  |
//|【引数】 ea_order_entry_Type:売買(0:買 1:売)                         |
//|【引数】 ea_order_stop_price:損切値  ea_order_good_price:利確値      |
//|【引数】 orderComment:オーダーコメント ea_order_MagicNo:マジックNo       |
//|                                                                  |
//|【戻値】True:成功                                                   |
bool funcOrder_Send(int ea_order_entry_Type, 
                    double ea_order_stop_price,
                    double ea_order_good_price,
                    int orderComment,
                    int ea_order_MagicNo)
{
        
   int order_resend_num;        // エントリー試行回数
   int ea_ticket_res;           // チケットNo
   int errorcode;               // エラーコード
   double ea_order_entry_price; // エントリーレート
   color order_Color;
   bool kekka = False;
          
   // エントリー試行回数上限:10回 
   for (order_resend_num = 0; order_resend_num < 10; order_resend_num++)
   {       
      if (MarketInfo(NULL, MODE_SPREAD) <= A_SPREAD)
      {
        
         if (ea_order_entry_Type == OP_BUY)
         {   
            ea_order_entry_price = Ask;               // 現在の買値でエントリー
            order_Color = clrBlue;
         }
         else if (ea_order_entry_Type == OP_SELL)
         {        
            ea_order_entry_price = Bid;               // 現在の売値でエントリー
            order_Color = clrRed;            
         }
        
         // FXCMでは新規エントリー時にストップ/リミットを設定出来ない。
         ea_ticket_res = OrderSend(   // 新規エントリー注文
            NULL,                 // 通貨ペア
            ea_order_entry_Type,      // オーダータイプ[OP_BUY / OP_SELL]
            Lots,                     // ロット[0.01単位](FXTFは1=10Lot)
            ea_order_entry_price,     // オーダープライスレート
            20,                       // スリップ上限    (int)[分解能 0.1pips]
            ea_order_stop_price,      // ストップレート
            ea_order_good_price,      // リミットレート
            orderComment,             // オーダーコメント
            ea_order_MagicNo,         // マジックナンバー(識別用)
            0,                        // オーダーリミット時間
            order_Color               // オーダーアイコンカラー
            );
      }
                    
      // 注文でエラーが出た場合                 
      if (ea_ticket_res == -1)
      {
         errorcode = GetLastError(); // エラーコード取得
        
         if(errorcode != ERR_NO_ERROR)
         {
            printf("エラー");
         }
        
         Sleep(2000);
         RefreshRates(); // レート更新
        
         printf("再エントリー要求回数:%d, 更新エントリーレート:%g",order_resend_num+1 ,ea_order_entry_price);
         kekka = False;
      }
      else
      {  // 注文約定
         Print("新規注文約定。 チケットNo=",ea_ticket_res," レート:",ea_order_entry_price);
         Sleep(300);                                           // 300msec待ち(オーダー要求頻度が多過ぎるとエラーになる為)
         kekka = True;           
         break;
      }
   }
   return kekka;   
}
        
//+------------------------------------------------------------------+
//|【関数】RCIのクロスを探す                                              
//|                                                                  
//|【引数】 IN OUT  引数名             説明                          
//|        ---------------------------------------------------------                                                           
//|       ○      limit              どこまで遡るか                   
//|       ○      i                  現在のBar位置                
//|【戻値】1:ロング 2:ショート 0:何もしない                             
//|                                                                  
//|【備考】なし                                                         
//+------------------------------------------------------------------+
int getRciSign(int limit, int i)
{
   int n;
   int sign = 0;
              
   limit = i + limit;
   i     = i + 1;
     
   for (n = i; n <= limit; n++)
   {
      double RCI_atai_TAN_1   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 0, n);    // RCI[短期]の値
      double RCI_atai_TAN_2   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 0, n + 1);// RCI[短期]の値(1つ過去)
      double RCI_atai_CHU_1   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 1, n);    // RCI[中期]の値
      double RCI_atai_CHU_2   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 1, n + 1);// RCI[中期]の値(1つ過去)
      double RCI_atai_CHO_1   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 2, n);    // RCI[長期]の値
      double RCI_atai_CHO_2   = iCustom(NULL, 0, "RCI", RCI_KIKAN1, RCI_KIKAN2, RCI_KIKAN3, RCI_VIEW_CNT, 2, n + 1);// RCI[長期]の値(1つ過去)
     
      // 短期RCIが買われすぎラインに到達し、中期または長期RCIが前回の値を上回っている場合
      if (RCI_atai_TAN_1 <= RCI_KAI && (RCI_atai_CHU_1 > RCI_atai_CHU_2 || RCI_atai_CHO_1 > RCI_atai_CHO_2))
      {
         // ロングのサイン
         sign = 1;
         break;
      }
      // 短期RCIが買われすぎラインに到達し、中期または長期RCIが前回の値を下回っている場合
      else if (RCI_atai_TAN_1 >= RCI_URI && (RCI_atai_CHU_1 < RCI_atai_CHU_2 || RCI_atai_CHO_1 < RCI_atai_CHO_2))      
      {
         // ショートのサイン
         sign = 2;
         break;
      }
   }         
          
   return(sign);
}
