unit Unit18030;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, CnStrings, CnWideStrings, CnGB18030, ExtCtrls;

type
  TFormGB18030 = class(TForm)
    grpTestGB2U: TGroupBox;
    btnGB18030CodePointToUtf16: TButton;
    btnGenGB18030UnicodeCompare: TButton;
    grpGenerate: TGroupBox;
    btnGenUtf16: TButton;
    btnGenGB18030Page: TButton;
    btnGenUtf16Page: TButton;
    chkIncludeCharValue: TCheckBox;
    btnGenGB18030PagePartly: TButton;
    grpMisc: TGroupBox;
    btnCodePointFromUtf161: TButton;
    btnCodePointFromUtf162: TButton;
    btnUtf16CharLength: TButton;
    btnUtf8CharLength: TButton;
    btnUtf8Encode: TButton;
    btnCodePointUtf16: TButton;
    btnCodePointUtf162: TButton;
    btnUtf8Decode: TButton;
    btnCodePointUtf163: TButton;
    btnGB18030ToUtf16: TButton;
    btn18030CodePoint1: TButton;
    btn18030CodePoint2: TButton;
    btn18030CodePoint3: TButton;
    btnCodePoint180301: TButton;
    btnCodePoint180302: TButton;
    btnCodePoint180303: TButton;
    btnMultiUtf16ToGB18030: TButton;
    btnMultiGB18030ToUtf16: TButton;
    dlgSave1: TSaveDialog;
    btnGenUtf16Page1: TButton;
    bvl1: TBevel;
    bvl2: TBevel;
    grpTestU2GB: TGroupBox;
    btnUtf16CodePointToGB180301: TButton;
    btnGenUnicodeGB18030Compare2: TButton;
    btnStringGB18030ToUnicode: TButton;
    btnStringUnicodeToGB18030: TButton;
    procedure btnCodePointFromUtf161Click(Sender: TObject);
    procedure btnCodePointFromUtf162Click(Sender: TObject);
    procedure btnUtf16CharLengthClick(Sender: TObject);
    procedure btnUtf8CharLengthClick(Sender: TObject);
    procedure btnUtf8EncodeClick(Sender: TObject);
    procedure btnCodePointUtf16Click(Sender: TObject);
    procedure btnCodePointUtf162Click(Sender: TObject);
    procedure btnUtf8DecodeClick(Sender: TObject);
    procedure btnGenUtf16Click(Sender: TObject);
    procedure btnCodePointUtf163Click(Sender: TObject);
    procedure btnGB18030ToUtf16Click(Sender: TObject);
    procedure btn18030CodePoint1Click(Sender: TObject);
    procedure btn18030CodePoint2Click(Sender: TObject);
    procedure btn18030CodePoint3Click(Sender: TObject);
    procedure btnCodePoint180301Click(Sender: TObject);
    procedure btnCodePoint180302Click(Sender: TObject);
    procedure btnCodePoint180303Click(Sender: TObject);
    procedure btnMultiUtf16ToGB18030Click(Sender: TObject);
    procedure btnMultiGB18030ToUtf16Click(Sender: TObject);
    procedure btnGenGB18030PageClick(Sender: TObject);
    procedure btnGenUtf16PageClick(Sender: TObject);
    procedure btnGB18030CodePointToUtf16Click(Sender: TObject);
    procedure btnGenGB18030PagePartlyClick(Sender: TObject);
    procedure btnGenGB18030UnicodeCompareClick(Sender: TObject);
    procedure btnGenUtf16Page1Click(Sender: TObject);
    procedure btnUtf16CodePointToGB180301Click(Sender: TObject);
    procedure btnGenUnicodeGB18030Compare2Click(Sender: TObject);
    procedure btnStringGB18030ToUnicodeClick(Sender: TObject);
  private
    // 以 Windows API 的方式批量生成 256 个 Unicode 字符
    procedure GenUtf16Page(Page: Byte; Content: TCnWideStringList);

    // 以 Windows API 的方式实现单个 Utf16 字符编码和 GB18030 字符编码的互转
    function APICodePointUtf16ToGB18030(UCP: TCnCodePoint): TCnCodePoint;
    function APICodePointGB18030ToUtf16(GBCP: TCnCodePoint): TCnCodePoint;

    // 生成指定范围内的 Utf16 字符到 GB18030 字符的映射
    procedure Gen2Utf16ToGB18030Page(FromH, FromL, ToH, ToL: Byte; Content: TCnAnsiStringList; H2: Word = 0);

    // 取到下一个四字节值的 GB18030 字符编码值
    procedure Step4GB18030CodePoint(var CP: TCnCodePoint);

    // 以 Windows API 的方式代码生成 GB1830 到 Unicode 的批量映射区间，供比对结果
    function Gen2GB18030ToUtf16Page(FromH, FromL, ToH, ToL: Byte; Content: TCnWideStringList): Integer;
    function Gen4GB18030ToUtf16Page(From4, To4: TCnCodePoint; Content: TCnWideStringList): Integer;

    // 以 Windows API 的方式代码生成 GB1830 到 Unicode 的映射数组内容，供 CnPack 编程使用
    function Gen2GB18030ToUtf16Array(FromH, FromL, ToH, ToL: Byte; CGB, CU: TCnWideStringList): Integer;
    function Gen4GB18030ToUtf16Array(From4, To4: TCnCodePoint; CGB, CU: TCnWideStringList): Integer;

    // 以 CnPack 的代码生成 GB1830 到 Unicode 的批量映射区间，供和上面 Windows API 的方式比对结果
    function GenCn2GB18030ToUtf16Page(FromH, FromL, ToH, ToL: Byte; Content: TCnAnsiStringList): Integer;
    function GenCn4GB18030ToUtf16Page(From4, To4: TCnCodePoint; Content: TCnAnsiStringList): Integer;

    // 以 Windows API 的方式代码生成 Unicode 到 GB1830 的批量映射区间
    function GenUnicodeToGB18030Page(FromU, ToU: TCnCodePoint; Content: TCnWideStringList): Integer;

    // 以 CnPack 的代码生成指定范围内的 Utf16 字符到 GB18030 字符的映射
    procedure GenCn2Utf16ToGB18030Page(FromH, FromL, ToH, ToL: Byte; Content: TCnAnsiStringList; H2: Word = 0);

  public

  end;

var
  FormGB18030: TFormGB18030;

implementation

uses
  CnNative;

{$R *.DFM}

const
  FACE: array[0..3] of Byte = ($3D, $D8, $02, $DE);      // 笑哭了的表情符的 UTF16-LE 表示
  FACE_UTF8: array[0..3] of Byte = ($F0, $9F, $98, $82); // 笑哭了的表情符的 UTF8-MB4 表示

  CP_GB18030 = 54936;

procedure TFormGB18030.btnCodePointFromUtf161Click(Sender: TObject);
var
  A: AnsiString;
  S: WideString;
  C: Cardinal;
begin
  A := '吃饭'; // 内存中是 B3D4B7B9，GB18030内码也是 B3D4 和 B7B9符合阅读顺序
  S := '吃饭'; // 内存中是 03546D99，但 Unicode 内码却是 5403 和 996D，有反置
  C := GetCodePointFromUtf16Char(PWideChar(S));
  ShowMessage(IntToHex(C, 2));
end;

procedure TFormGB18030.btnCodePointFromUtf162Click(Sender: TObject);
var
  S: WideString;
  C: Cardinal;
begin
  SetLength(S, 2);
  Move(FACE[0], S[1], 4);

  C := GetCodePointFromUtf16Char(PWideChar(S));
  ShowMessage(IntToHex(C, 2)); // 应得到 $1F602
end;

procedure TFormGB18030.btnUtf16CharLengthClick(Sender: TObject);
var
  S: WideString;
  C: Cardinal;
begin
  SetLength(S, 2);
  Move(FACE[0], S[1], 4);

  C := GetCharLengthFromUtf16(PWideChar(S));
  ShowMessage(IntToStr(C)); // 应得到 1
end;

procedure TFormGB18030.btnUtf8CharLengthClick(Sender: TObject);
var
  S: AnsiString;
  C: Cardinal;
begin
  SetLength(S, 4);
  Move(FACE_UTF8[0], S[1], 4);

  C := GetCharLengthFromUtf8(PAnsiChar(S));
  ShowMessage(IntToStr(C)); // 应得到 1
end;

procedure TFormGB18030.btnUtf8EncodeClick(Sender: TObject);
var
  S: WideString;
  R: AnsiString;
begin
  SetLength(S, 2);
  Move(FACE[0], S[1], 4);

  R := CnUtf8EncodeWideString(S);
  if R <> '' then
    ShowMessage(DataToHex(@R[1], Length(R)))  // F09F9882
  else
    ShowMessage('Error');
end;

procedure TFormGB18030.btnCodePointUtf16Click(Sender: TObject);
var
  S: WideString;
  C: Cardinal;
begin
  C := $5403;  // 吃的 Unicode 码点
  SetLength(S, 1);
  GetUtf16CharFromCodePoint(C, @S[1]);
  ShowMessage(S);
end;

procedure TFormGB18030.btnCodePointUtf162Click(Sender: TObject);
var
  S: WideString;
  C: Cardinal;
begin
  C := $1F602;  // 笑哭了的表情符的 Unicode 码点
  SetLength(S, 2);
  GetUtf16CharFromCodePoint(C, @S[1]);
  ShowMessage(DataToHex(@S[1], Length(S) * SizeOf(WideChar))); // $3DD802DE
end;

procedure TFormGB18030.btnUtf8DecodeClick(Sender: TObject);
var
  S: AnsiString;
  R: WideString;
begin
  SetLength(S, 4);
  Move(FACE_UTF8[0], S[1], 4);

  R := CnUtf8DecodeToWideString(S);
  if R <> '' then
    ShowMessage(DataToHex(@R[1], Length(R) * SizeOf(WideChar)))  // 3DD802DE
  else
    ShowMessage('Error');
end;

procedure TFormGB18030.btnGenUtf16Click(Sender: TObject);
var
  I: Integer;
  WS: TCnWideStringList;
begin
  // 0000 ~ FFFF，一行 0~F，一页 0~F，共 255 页
  WS := TCnWideStringList.Create;
  Screen.Cursor := crHourGlass;

  try
    for I := 0 to 255 do
    begin
      WS.Add('');
      GenUtf16Page(I, WS);
    end;

    dlgSave1.FileName := 'UTF16.txt';
    if dlgSave1.Execute then
    begin
      WS.SaveToFile(dlgSave1.FileName);
      ShowMessage('Save to ' + dlgSave1.FileName);
    end;
  finally
    Screen.Cursor := crDefault;
    WS.Free;
  end;
end;

procedure TFormGB18030.GenUtf16Page(Page: Byte; Content: TCnWideStringList);
var
  R, C: Byte;
  S, T: WideString;
begin
  S := '    ';
  for C := 0 to $F do
    S := S + ' ' + IntToHex(C, 2);
  Content.Add(S);

  SetLength(T, 1);
  for R := 0 to $F do
  begin
    S := IntToHex(Page, 2) + IntToHex(16 * R, 2);
    for C := 0 to $F do
    begin
      GetUtf16CharFromCodePoint(Page * 256 + R * 16 + C, @T[1]);
      S := S + ' ' + T;
    end;
    Content.Add(S);
  end;
end;

procedure TFormGB18030.btnCodePointUtf163Click(Sender: TObject);
var
  S: WideString;
  C: Cardinal;
begin
  C := $20BB7;  // 上土下口 的 Unicode 码点
  SetLength(S, 2);
  GetUtf16CharFromCodePoint(C, @S[1]);
  ShowMessage(DataToHex(@S[1], Length(S) * SizeOf(WideChar))); // $42D8B7DF
end;

procedure TFormGB18030.btnGB18030ToUtf16Click(Sender: TObject);
var
  S: AnsiString;
  W: WideString;
  C: Integer;
begin
  S := '吃饭';

  C := MultiByteToWideChar(CP_GB18030, 0, @S[1], Length(S), nil, 0);
  if C > 0 then
  begin
    SetLength(W, C);
    C := MultiByteToWideChar(CP_GB18030, 0, @S[1], Length(S), @W[1], Length(W));

    if C > 0 then
    begin
      ShowMessage(W);

      C := WideCharToMultiByte(CP_GB18030, 0, @W[1], Length(W), nil, 0, nil, nil);
      if C > 0 then
      begin
        SetLength(S, C);

        C := WideCharToMultiByte(CP_GB18030, 0, @W[1], Length(W), @S[1], Length(S), nil, nil);
        if C > 0 then
          ShowMessage(S);
      end;
    end;
  end;
end;

procedure TFormGB18030.btn18030CodePoint1Click(Sender: TObject);
var
  S: AnsiString;
  C: TCnCodePoint;
begin
  S := 'A';
  C := GetCodePointFromGB18030Char(@S[1]);
  ShowMessage(IntToHex(C, 2));              // 41
end;

procedure TFormGB18030.btn18030CodePoint2Click(Sender: TObject);
var
  S: AnsiString;
  C: TCnCodePoint;
begin
  S := '吃';
  C := GetCodePointFromGB18030Char(@S[1]);
  ShowMessage(IntToHex(C, 2));              // B3D4
end;

procedure TFormGB18030.btn18030CodePoint3Click(Sender: TObject);
var
  S: AnsiString;
  C: TCnCodePoint;
begin
  SetLength(S, 4);
  S[1] := #$82;   // 左女右敖
  S[2] := #$30;
  S[3] := #$C2;
  S[4] := #$30;

  C := GetCodePointFromGB18030Char(@S[1]);
  ShowMessage(IntToHex(C, 2));              // 8230C230
end;

procedure TFormGB18030.btnCodePoint180301Click(Sender: TObject);
var
  S: AnsiString;
  C: Cardinal;
begin
  C := $42;  // B 的 GB18030 码点
  SetLength(S, 1);
  GetGB18030CharsFromCodePoint(C, @S[1]);
  ShowMessage(S);
end;

procedure TFormGB18030.btnCodePoint180302Click(Sender: TObject);
var
  S: AnsiString;
  C: Cardinal;
begin
  C := $B3D4;  // 吃的 GB18030 码点
  SetLength(S, 2);
  GetGB18030CharsFromCodePoint(C, @S[1]);
  ShowMessage(S);
end;

procedure TFormGB18030.btnCodePoint180303Click(Sender: TObject);
var
  S: AnsiString;
  C: Cardinal;
begin
  C := $8139EF34;  // 一个大叉 GB18030 码点
  SetLength(S, 4);
  GetGB18030CharsFromCodePoint(C, @S[1]);   // 内存中得到 8139EF34
  ShowMessage(S);
end;

function TFormGB18030.APICodePointGB18030ToUtf16(GBCP: TCnCodePoint): TCnCodePoint;
var
  S: AnsiString;
  W: WideString;
  C, T: Integer;
begin
  Result := CN_INVALID_CODEPOINT;

  SetLength(S, 4); // 最多 4
  C := GetGB18030CharsFromCodePoint(GBCP, @S[1]);  // S 是该 GB18030 字符，C 是其字节长度

  T := MultiByteToWideChar(CP_GB18030, 0, @S[1], C, nil, 0);
  if T > 0 then
  begin
    SetLength(W, T);
    T := MultiByteToWideChar(CP_GB18030, 0, @S[1], C, @W[1], Length(W));
    if T > 0 then
      Result := GetCodePointFromUtf16Char(@W[1]);
  end;
end;

function TFormGB18030.APICodePointUtf16ToGB18030(UCP: TCnCodePoint): TCnCodePoint;
var
  S: AnsiString;
  W: WideString;
  C, T: Integer;
begin
  Result := CN_INVALID_CODEPOINT;

  SetLength(W, 2); // 最多 2 个宽字符也就是四字节
  C := GetUtf16CharFromCodePoint(UCP, @W[1]);  // W 是该 Utf16 字符，C 是其宽字符长度

  T := WideCharToMultiByte(CP_GB18030, 0, @W[1], C, nil, 0, nil, nil);
  if T > 0 then
  begin
    SetLength(S, T);

    T := WideCharToMultiByte(CP_GB18030, 0, @W[1], C, @S[1], Length(S), nil, nil);
    if T > 0 then
      Result := GetCodePointFromGB18030Char(@S[1]);
  end;
end;

procedure TFormGB18030.btnMultiUtf16ToGB18030Click(Sender: TObject);
var
  S: WideString;
  A, T: AnsiString;
  I: Integer;
  C: TCnCodePoint;
begin
  S := '吃饭一半少，睡觉三周多';
  A := '';
  for I := 1 to Length(S) do
  begin
    C := GetCodePointFromUtf16Char(@S[I]);   // Utf16 值
    if C = CN_INVALID_CODEPOINT then
      Exit;

    C := APICodePointUtf16ToGB18030(C);         // 转成 GB18030
    if C = CN_INVALID_CODEPOINT then
      Exit;

    SetLength(T, 4);
    C := GetGB18030CharsFromCodePoint(C, @T[1]);
    if C > 0 then
      SetLength(T, C);

    A := A + T;
  end;
  ShowMessage(A);
end;

procedure TFormGB18030.btnMultiGB18030ToUtf16Click(Sender: TObject);
var
  S, T: WideString;
  A: AnsiString;
  I: Integer;
  C: TCnCodePoint;
begin
  A := '吃饭一半少，睡觉三周多';
  S := '';
  I := 1;

  while I <= Length(A) do
  begin
    C := GetCodePointFromGB18030Char(@A[I]);   // GB18030 值
    Inc(I, 2);

    if C = CN_INVALID_CODEPOINT then
      Exit;

    C := APICodePointGB18030ToUtf16(C);           // 转成 Utf16
    if C = CN_INVALID_CODEPOINT then
      Exit;

    SetLength(T, 1);
    GetUtf16CharFromCodePoint(C, @T[1]);

    S := S + T;
  end;
  ShowMessage(S);
end;

function TFormGB18030.Gen2GB18030ToUtf16Page(FromH, FromL, ToH, ToL: Byte;
  Content: TCnWideStringList): Integer;
var
  H, L, T: Integer;
  GBCP, UCP: TCnCodePoint;
  S, C: WideString;
begin
  Result := 0;
  for H := FromH to ToH do
  begin
    for L := FromL to ToL do
    begin
      GBCP := (H shl 8) or L;
      UCP := APICodePointGB18030ToUtf16(GBCP);
      T := GetUtf16CharFromCodePoint(UCP, nil);
      SetLength(C, T);
      GetUtf16CharFromCodePoint(UCP, @C[1]);

      if chkIncludeCharValue.Checked then
        S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2) + '  ' + C
      else
        S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2);

      Content.Add(S);
      Inc(Result);
    end;
  end;
end;

procedure TFormGB18030.btnGenGB18030PageClick(Sender: TObject);
var
  R, I: Integer;
  WS: TCnWideStringList;
  ASS: TCnAnsiStringList;
begin
  WS := TCnWideStringList.Create;
// 双字节：A1A9~A1FE                     1 区
//         A840~A97E, A880~A9A0          5 区
//         B0A1~F7FE                     2 区汉字
//         8140~A07E, 8180~A0FE          3 区汉字
//         AA40~FE7E, AA80~FEA0          4 区汉字
//         AAA1~AFFE                     用户 1 区
//         F8A1~FEFE                     用户 2 区
//         A140~A77E, A180~A7A0          用户 3 区

  R := 0;
  WS.Add('区：双字节一; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($A1, $A1, $A9, $FE, WS);
  WS.Add('区：双字节五; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($A8, $40, $A9, $7E, WS);
  R := R + Gen2GB18030ToUtf16Page($A8, $80, $A9, $A0, WS);
  WS.Add('区：双字节汉字二; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($B0, $A1, $F7, $FE, WS);
  WS.Add('区：双字节汉字三; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($81, $40, $A0, $7E, WS);
  R := R + Gen2GB18030ToUtf16Page($81, $80, $A0, $FE, WS);
  WS.Add('区：双字节汉字四; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($AA, $40, $FE, $7E, WS);
  R := R + Gen2GB18030ToUtf16Page($AA, $80, $FE, $A0, WS);

  WS.Add('区：双字节用户一; 上一区字符数：' + IntToStr(R)); // 三个双字节用户区
  R := Gen2GB18030ToUtf16Page($AA, $A1, $AF, $FE, WS);
  WS.Add('区：双字节用户二; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($F8, $A1, $FE, $FE, WS);
  WS.Add('区：双字节用户三; 上一区字符数：' + IntToStr(R));
  R := Gen2GB18030ToUtf16Page($A1, $40, $A7, $7E, WS);
  R := R + Gen2GB18030ToUtf16Page($A1, $80, $A7, $A0, WS);

  // 四字节
  WS.Add('区：分隔一; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81308130, $81318131, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文一; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81318132, $81319934, WS);

  WS.Add('区：分隔二; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81319935, $8132E833, WS);

  WS.Add('区：四字节藏文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8132E834, $8132FD31, WS);

  WS.Add('区：分隔三; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8132FD32, $81339D35, WS);

  WS.Add('区：四字节朝鲜文字母; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81339D36, $8133B635, WS);

  WS.Add('区：分隔四; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8133B636, $8134D237, WS);

  WS.Add('区：四字节蒙古文（包括满文、托忒文、锡伯文和阿礼嘎礼字）; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8134D238, $8134E337, WS);

  WS.Add('区：分隔五; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8134E338, $8134F433, WS);

  WS.Add('区：四字节德宏傣文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8134F434, $8134F830, WS);

  WS.Add('区：分隔六; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8134F831, $8134F931, WS);

  WS.Add('区：四字节西双版纳新傣文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8134F932, $81358437, WS);

  WS.Add('区：分隔七; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81358438, $81358B31, WS);

  WS.Add('区：四字节西双版纳老傣文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81358B32, $81359935, WS);

  WS.Add('区：分隔八; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81359936, $81398B31, WS);

  WS.Add('区：四字节康熙部首; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($81398B32, $8139A135, WS);

  WS.Add('区：分隔九; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8139A136, $8139A932, WS);

  WS.Add('区：四字节朝鲜文兼容字母; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8139A933, $8139B734, WS);

  WS.Add('区：分隔十; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8139B735, $8139EE38, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 A; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8139EE39, $82358738, WS);

  WS.Add('区：分隔十一; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82358739, $82358F32, WS);

  WS.Add('区：四字节 CJK 统一汉字; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82358F33, $82359636, WS);

  WS.Add('区：分隔十二; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82359637, $82359832, WS);

  WS.Add('区：四字节彝文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82359833, $82369435, WS);

  WS.Add('区：分隔十三; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82369436, $82369534, WS);

  WS.Add('区：四字节傈僳文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82369535, $82369A32, WS);

  WS.Add('区：分隔十四; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($82369A33, $8237CF34, WS);

  WS.Add('区：四字节朝鲜文音节; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8237CF35, $8336BE36, WS);

  WS.Add('区：分隔十五; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8336BE37, $8430BA31, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文二; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8430BA32, $8430FE35, WS);

  WS.Add('区：分隔十六; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($8430FE36, $84318639, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文三; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($84318730, $84319530, WS);

  WS.Add('区：分隔十七; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($84319531, $8431A439, WS);

  WS.Add('区：四字节蒙古文 BIRGA; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9034C538, $9034C730, WS);

  WS.Add('区：分隔十八; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9034C731, $9232C635, WS);

  WS.Add('区：四字节滇东北苗文; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9232C636, $9232D635, WS);

  WS.Add('区：分隔十九; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9232D636, $95328235, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 B; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($95328236, $9835F336, WS);

  WS.Add('区：分隔二十; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9835F337, $9835F737, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 C; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9835F738, $98399E36, WS);

  WS.Add('区：分隔二十一; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($98399E37, $98399F37, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 D; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($98399F38, $9839B539, WS);

  WS.Add('区：分隔二十二; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9839B630, $9839B631, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 E; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9839B632, $9933FE33, WS);

  WS.Add('区：分隔二十三; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9933FE34, $99348137, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 F; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($99348138, $9939F730, WS);

  WS.Add('区：分隔二十四; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($9939F731, $9A348431, WS);

  WS.Add('区：四字节用户扩展; 上一区字符数：' + IntToStr(R));
  R := Gen4GB18030ToUtf16Page($FD308130, $FE39FE39, WS);
  WS.Add('区：尾; 上一区字符数：' + IntToStr(R));

  dlgSave1.FileName := 'GB18030_UTF16.txt';
  if dlgSave1.Execute then
  begin
    if chkIncludeCharValue.Checked then
      WS.SaveToFile(dlgSave1.FileName)
    else
    begin
      ASS := TCnAnsiStringList.Create;
      for I := 0 to WS.Count - 1 do
        ASS.Add(WS[I]);
      ASS.SaveToFile(dlgSave1.FileName);
      ASS.Free;
    end;
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;
  WS.Free;
end;

procedure TFormGB18030.btnGenUtf16PageClick(Sender: TObject);
var
  SL: TCnAnsiStringList;
begin
  SL := TCnAnsiStringList.Create;

  Gen2Utf16ToGB18030Page(0, 0, $FF, $FF, SL);
  Gen2Utf16ToGB18030Page(0, 0, $FF, $FF, SL, 1);
  Gen2Utf16ToGB18030Page(0, 0, $FF, $FF, SL, 2);

  dlgSave1.FileName := 'UTF16_GB18030.txt';
  if dlgSave1.Execute then
  begin
    SL.SaveToFile(dlgSave1.FileName);
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;
  SL.Free;
end;

procedure TFormGB18030.Gen2Utf16ToGB18030Page(FromH, FromL, ToH, ToL: Byte;
  Content: TCnAnsiStringList; H2: Word);
var
  H, L, T: Integer;
  GBCP, UCP: TCnCodePoint;
  S, C: AnsiString;
begin
  for H := FromH to ToH do
  begin
    for L := FromL to ToL do
    begin
      UCP := ((H shl 8) or L) + (H2 shl 16);
      GBCP := APICodePointUtf16ToGB18030(UCP);
      if GBCP <> CN_INVALID_CODEPOINT then
      begin
        T := GetGB18030CharsFromCodePoint(GBCP, nil);
        SetLength(C, T);
        GetGB18030CharsFromCodePoint(GBCP, @C[1]);

        if chkIncludeCharValue.Checked then
          S := IntToHex(UCP, 2) + ' = ' + IntToHex(GBCP, 2) + '  ' + C
        else
          S := IntToHex(UCP, 2) + ' = ' + IntToHex(GBCP, 2);
      end
      else
        S := IntToHex(UCP, 2) + ' = ';

      Content.Add(S);
    end;
  end;
end;

function TFormGB18030.Gen4GB18030ToUtf16Page(From4, To4: TCnCodePoint;
  Content: TCnWideStringList): Integer;
var
  GBCP, UCP: TCnCodePoint;
  T: Integer;
  S, C: WideString;
begin
  Result := 0;
  GBCP := From4;
  while GBCP <= To4 do
  begin
    UCP := APICodePointGB18030ToUtf16(GBCP);
    T := GetUtf16CharFromCodePoint(UCP, nil);
    SetLength(C, T);
    GetUtf16CharFromCodePoint(UCP, @C[1]);

    if chkIncludeCharValue.Checked then
      S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2) + '  ' + C
    else
      S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2);

    Content.Add(S);
    Inc(Result);

    Step4GB18030CodePoint(GBCP);
  end;
end;

procedure TFormGB18030.btnGB18030CodePointToUtf16Click(Sender: TObject);
var
  GBCP, UCP: TCnCodePoint;
begin
  GBCP := $81308130;
  UCP := GetUnicodeFromGB18030CodePoint(GBCP);
  ShowMessage(IntToHex(UCP, 2));
end;

procedure TFormGB18030.btnGenGB18030PagePartlyClick(Sender: TObject);
var
  WSGB, WSU: TCnWideStringList;
  ASS: TCnAnsiStringList;
  SB: TCnStringBuilder;

  procedure AddSep;
  begin
    WSGB.Add('');
    WSU.Add('');
  end;

  procedure Combine(OutAss: TCnAnsiStringList; AWS: TCnWideStringList);
  var
    I: Integer;
  begin
    for I := 0 to AWS.Count - 1 do
    begin
      if AWS[I] <> '' then
      begin
        SB.Append(AWS[I]);
        if I < AWS.Count - 1 then
          SB.Append(',');
        if (SB.CharLength >= 80) or (I = AWS.Count - 1) then
        begin
          OutAss.Add('    ' + SB.ToString);
          SB.Clear;
        end
        else
          SB.Append(' ');
      end;
    end;
    OutAss.Add('  );');
  end;

begin
  WSGB := TCnWideStringList.Create;
  WSU := TCnWideStringList.Create;
  ASS := TCnAnsiStringList.Create;
  SB := TCnStringBuilder.Create;

  // 双字节一
  Gen2GB18030ToUtf16Array($A1, $A1, $A9, $FE, WSGB, WSU);
  // 双字节五
  Gen2GB18030ToUtf16Array($A8, $40, $A9, $7E, WSGB, WSU);
  Gen2GB18030ToUtf16Array($A8, $80, $A9, $A0, WSGB, WSU);
  // 双字节汉字二
  Gen2GB18030ToUtf16Array($B0, $A1, $F7, $FE, WSGB, WSU);
  // 双字节汉字三
  Gen2GB18030ToUtf16Array($81, $40, $A0, $7E, WSGB, WSU);
  Gen2GB18030ToUtf16Array($81, $80, $A0, $FE, WSGB, WSU);
  // 双字节汉字四
  Gen2GB18030ToUtf16Array($AA, $40, $FE, $7E, WSGB, WSU);
  Gen2GB18030ToUtf16Array($AA, $80, $FE, $A0, WSGB, WSU);

  // 双字节用户三
  Gen2GB18030ToUtf16Array($A1, $40, $A7, $7E, WSGB, WSU);
  Gen2GB18030ToUtf16Array($A1, $80, $A7, $A0, WSGB, WSU);

  ASS.Add('');
  ASS.Add('  CN_GB18030_2MAPPING: array[0..' + IntToStr(WSGB.Count - 1) + '] of TCnCodePoint = (');
  Combine(ASS, WSGB);
  ASS.Add('');
  ASS.Add('  CN_UNICODE_2MAPPING: array[0..' + IntToStr(WSU.Count - 1) + '] of TCnCodePoint = (');
  Combine(ASS, WSU);
  ASS.Add('');

  WSGB.Clear;
  WSU.Clear;

  // 四字节
  // 分隔一
  Gen4GB18030ToUtf16Array($81308130, $81318131, WSGB, WSU);

  // 分隔八
  Gen4GB18030ToUtf16Array($81359936, $81398B31, WSGB, WSU);

  // 分隔九
  Gen4GB18030ToUtf16Array($8139A136, $8139A932, WSGB, WSU);

  // 分隔十
  Gen4GB18030ToUtf16Array($8139B735, $8139EE38, WSGB, WSU);

  // CJK 统一汉字扩充 A
  Gen4GB18030ToUtf16Array($8139EE39, $82358738, WSGB, WSU);

  // 分隔十五
  Gen4GB18030ToUtf16Array($8336BE37, $8430BA31, WSGB, WSU);

  // 分隔十六
  Gen4GB18030ToUtf16Array($8430FE36, $84318639, WSGB, WSU);

  // 分隔十七
  Gen4GB18030ToUtf16Array($84319531, $8431A439, WSGB, WSU);

  ASS.Add('  CN_GB18030_4MAPPING: array[0..' + IntToStr(WSGB.Count - 1) + '] of TCnCodePoint = (');
  Combine(ASS, WSGB);
  ASS.Add('');
  ASS.Add('  CN_UNICODE_4MAPPING: array[0..' + IntToStr(WSU.Count - 1) + '] of TCnCodePoint = (');
  Combine(ASS, WSU);
  ASS.Add('');

  dlgSave1.FileName := 'GB18030_Unicode.inc';
  if dlgSave1.Execute then
  begin
    ASS.SaveToFile(dlgSave1.FileName);
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;

  SB.Free;
  ASS.Free;
  WSGB.Free;
  WSU.Free;
end;

function TFormGB18030.Gen2GB18030ToUtf16Array(FromH, FromL, ToH, ToL: Byte;
  CGB, CU: TCnWideStringList): Integer;
var
  H, L, T: Integer;
  GBCP, UCP: TCnCodePoint;
  C: WideString;
begin
  Result := 0;
  for H := FromH to ToH do
  begin
    for L := FromL to ToL do
    begin
      GBCP := (H shl 8) or L;
      UCP := APICodePointGB18030ToUtf16(GBCP);
      T := GetUtf16CharFromCodePoint(UCP, nil);
      SetLength(C, T);
      GetUtf16CharFromCodePoint(UCP, @C[1]);

      CGB.Add('$' + Format('%4.4x', [GBCP]));
      CU.Add('$' + Format('%4.4x', [UCP]));

      Inc(Result);
    end;
  end;
end;

function TFormGB18030.Gen4GB18030ToUtf16Array(From4, To4: TCnCodePoint;
  CGB, CU: TCnWideStringList): Integer;
var
  GBCP, UCP: TCnCodePoint;
  T: Integer;
  C: WideString;
begin
  Result := 0;
  GBCP := From4;
  while GBCP <= To4 do
  begin
    UCP := APICodePointGB18030ToUtf16(GBCP);
    T := GetUtf16CharFromCodePoint(UCP, nil);
    SetLength(C, T);
    GetUtf16CharFromCodePoint(UCP, @C[1]);

    CGB.Add('$' + IntToHex(GBCP, 2));
    CU.Add('$' + IntToHex(UCP, 2));

    Inc(Result);
    Step4GB18030CodePoint(GBCP);
  end;
end;

procedure TFormGB18030.Step4GB18030CodePoint(var CP: TCnCodePoint);
var
  B2, B3, B4: Byte;
begin
  repeat
    Inc(CP);
    B4 := Byte(CP);
    B3 := Byte(CP shr 8);
    B2 := Byte(CP shr 16);
  until (B4 in [$30..$39]) and (B3 in [$81..$FE]) and (B2 in [$30..$39]);
end;

procedure TFormGB18030.btnGenGB18030UnicodeCompareClick(Sender: TObject);
var
  R: Integer;
  WS: TCnAnsiStringList;
begin
  WS := TCnAnsiStringList.Create;
// 双字节：A1A9~A1FE                     1 区
//         A840~A97E, A880~A9A0          5 区
//         B0A1~F7FE                     2 区汉字
//         8140~A07E, 8180~A0FE          3 区汉字
//         AA40~FE7E, AA80~FEA0          4 区汉字
//         AAA1~AFFE                     用户 1 区
//         F8A1~FEFE                     用户 2 区
//         A140~A77E, A180~A7A0          用户 3 区

  R := 0;
  WS.Add('区：双字节一; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($A1, $A1, $A9, $FE, WS);
  WS.Add('区：双字节五; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($A8, $40, $A9, $7E, WS);
  R := R + GenCn2GB18030ToUtf16Page($A8, $80, $A9, $A0, WS);
  WS.Add('区：双字节汉字二; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($B0, $A1, $F7, $FE, WS);
  WS.Add('区：双字节汉字三; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($81, $40, $A0, $7E, WS);
  R := R + GenCn2GB18030ToUtf16Page($81, $80, $A0, $FE, WS);
  WS.Add('区：双字节汉字四; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($AA, $40, $FE, $7E, WS);
  R := R + GenCn2GB18030ToUtf16Page($AA, $80, $FE, $A0, WS);

  WS.Add('区：双字节用户一; 上一区字符数：' + IntToStr(R)); // 三个双字节用户区
  R := GenCn2GB18030ToUtf16Page($AA, $A1, $AF, $FE, WS);
  WS.Add('区：双字节用户二; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($F8, $A1, $FE, $FE, WS);
  WS.Add('区：双字节用户三; 上一区字符数：' + IntToStr(R));
  R := GenCn2GB18030ToUtf16Page($A1, $40, $A7, $7E, WS);
  R := R + GenCn2GB18030ToUtf16Page($A1, $80, $A7, $A0, WS);

  // 四字节
  WS.Add('区：分隔一; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81308130, $81318131, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文一; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81318132, $81319934, WS);

  WS.Add('区：分隔二; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81319935, $8132E833, WS);

  WS.Add('区：四字节藏文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8132E834, $8132FD31, WS);

  WS.Add('区：分隔三; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8132FD32, $81339D35, WS);

  WS.Add('区：四字节朝鲜文字母; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81339D36, $8133B635, WS);

  WS.Add('区：分隔四; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8133B636, $8134D237, WS);

  WS.Add('区：四字节蒙古文（包括满文、托忒文、锡伯文和阿礼嘎礼字）; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8134D238, $8134E337, WS);

  WS.Add('区：分隔五; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8134E338, $8134F433, WS);

  WS.Add('区：四字节德宏傣文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8134F434, $8134F830, WS);

  WS.Add('区：分隔六; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8134F831, $8134F931, WS);

  WS.Add('区：四字节西双版纳新傣文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8134F932, $81358437, WS);

  WS.Add('区：分隔七; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81358438, $81358B31, WS);

  WS.Add('区：四字节西双版纳老傣文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81358B32, $81359935, WS);

  WS.Add('区：分隔八; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81359936, $81398B31, WS);

  WS.Add('区：四字节康熙部首; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($81398B32, $8139A135, WS);

  WS.Add('区：分隔九; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8139A136, $8139A932, WS);

  WS.Add('区：四字节朝鲜文兼容字母; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8139A933, $8139B734, WS);

  WS.Add('区：分隔十; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8139B735, $8139EE38, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 A; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8139EE39, $82358738, WS);

  WS.Add('区：分隔十一; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82358739, $82358F32, WS);

  WS.Add('区：四字节 CJK 统一汉字; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82358F33, $82359636, WS);

  WS.Add('区：分隔十二; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82359637, $82359832, WS);

  WS.Add('区：四字节彝文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82359833, $82369435, WS);

  WS.Add('区：分隔十三; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82369436, $82369534, WS);

  WS.Add('区：四字节傈僳文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82369535, $82369A32, WS);

  WS.Add('区：分隔十四; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($82369A33, $8237CF34, WS);

  WS.Add('区：四字节朝鲜文音节; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8237CF35, $8336BE36, WS);

  WS.Add('区：分隔十五; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8336BE37, $8430BA31, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文二; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8430BA32, $8430FE35, WS);

  WS.Add('区：分隔十六; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($8430FE36, $84318639, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文三; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($84318730, $84319530, WS);

  WS.Add('区：分隔十七; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($84319531, $8431A439, WS);

  WS.Add('区：四字节蒙古文 BIRGA; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9034C538, $9034C730, WS);

  WS.Add('区：分隔十八; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9034C731, $9232C635, WS);

  WS.Add('区：四字节滇东北苗文; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9232C636, $9232D635, WS);

  WS.Add('区：分隔十九; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9232D636, $95328235, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 B; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($95328236, $9835F336, WS);

  WS.Add('区：分隔二十; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9835F337, $9835F737, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 C; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9835F738, $98399E36, WS);

  WS.Add('区：分隔二十一; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($98399E37, $98399F37, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 D; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($98399F38, $9839B539, WS);

  WS.Add('区：分隔二十二; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9839B630, $9839B631, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 E; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9839B632, $9933FE33, WS);

  WS.Add('区：分隔二十三; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9933FE34, $99348137, WS);

  WS.Add('区：四字节 CJK 统一汉字扩充 F; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($99348138, $9939F730, WS);

  WS.Add('区：分隔二十四; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($9939F731, $9A348431, WS);

  WS.Add('区：四字节用户扩展; 上一区字符数：' + IntToStr(R));
  R := GenCn4GB18030ToUtf16Page($FD308130, $FE39FE39, WS);
  WS.Add('区：尾; 上一区字符数：' + IntToStr(R));

  dlgSave1.FileName := 'GB18030_UTF16_CN.txt';
  if dlgSave1.Execute then
  begin
    WS.SaveToFile(dlgSave1.FileName);
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;
  WS.Free;
end;

function TFormGB18030.GenCn4GB18030ToUtf16Page(From4, To4: TCnCodePoint;
  Content: TCnAnsiStringList): Integer;
var
  GBCP, UCP: TCnCodePoint;
  S: AnsiString;
begin
  Result := 0;
  GBCP := From4;
  while GBCP <= To4 do
  begin
    UCP := GetUnicodeFromGB18030CodePoint(GBCP);
    S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2);

    Content.Add(S);
    Inc(Result);

    Step4GB18030CodePoint(GBCP);
  end;
end;

function TFormGB18030.GenCn2GB18030ToUtf16Page(FromH, FromL, ToH,
  ToL: Byte; Content: TCnAnsiStringList): Integer;
var
  H, L: Integer;
  GBCP, UCP: TCnCodePoint;
  S: AnsiString;
begin
  Result := 0;
  for H := FromH to ToH do
  begin
    for L := FromL to ToL do
    begin
      GBCP := (H shl 8) or L;
      UCP := GetUnicodeFromGB18030CodePoint(GBCP);
      S := IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2);

      Content.Add(S);
      Inc(Result);
    end;
  end;
end;

procedure TFormGB18030.btnGenUtf16Page1Click(Sender: TObject);
var
  R, I: Integer;
  WS: TCnWideStringList;
  ASS: TCnAnsiStringList;
begin
  WS := TCnWideStringList.Create;
// 双字节：A1A9~A1FE                     1 区
//         A840~A97E, A880~A9A0          5 区
//         B0A1~F7FE                     2 区汉字
//         8140~A07E, 8180~A0FE          3 区汉字
//         AA40~FE7E, AA80~FEA0          4 区汉字
//         AAA1~AFFE                     用户 1 区
//         F8A1~FEFE                     用户 2 区
//         A140~A77E, A180~A7A0          用户 3 区

  R := 0;

  WS.Add('区：双字节用户一; 上一区字符数：' + IntToStr(R)); // 三个双字节用户区
  R := GenUnicodeToGB18030Page($E000, $E233, WS);
  WS.Add('区：双字节用户二; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($E234, $E4C5, WS);


  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文一; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($060C, $1AAF, WS);

  WS.Add('区：四字节康熙部首; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($2F00, $2FDF, WS);

  WS.Add('区：四字节朝鲜文兼容字母; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($3131, $31BE, WS);

  WS.Add('区：分隔十一; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($4DB6, $4DFF, WS);

  WS.Add('区：四字节 CJK 统一汉字; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($9FA6, $D7A3, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文二; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($FB50, $FDFE, WS);

  WS.Add('区：四字节维吾尔、哈萨克、柯尔克孜文三; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($FE70, $FEFC, WS);

  WS.Add('区：四字节蒙古文 BIRGA; 上一区字符数：' + IntToStr(R));
  R := GenUnicodeToGB18030Page($11660, $2FFFF, WS);

  WS.Add('区：尾; 上一区字符数：' + IntToStr(R));

  dlgSave1.FileName := 'UTF16_GB18030_API.txt';
  if dlgSave1.Execute then
  begin
    if chkIncludeCharValue.Checked then
      WS.SaveToFile(dlgSave1.FileName)
    else
    begin
      ASS := TCnAnsiStringList.Create;
      for I := 0 to WS.Count - 1 do
        ASS.Add(WS[I]);
      ASS.SaveToFile(dlgSave1.FileName);
      ASS.Free;
    end;
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;
  WS.Free;
end;

function TFormGB18030.GenUnicodeToGB18030Page(FromU, ToU: TCnCodePoint;
  Content: TCnWideStringList): Integer;
var
  T: Integer;
  UCP, GBCP: TCnCodePoint;
  S: AnsiString;
begin
  Result := 0;
  UCP := FromU;
  while UCP <= ToU do
  begin
    GBCP := APICodePointUtf16ToGB18030(UCP);
    if GBCP <> CN_INVALID_CODEPOINT then
    begin
      T := GetGB18030CharsFromCodePoint(GBCP, nil);
      if T > 0 then
      begin
        SetLength(S, T);
        GetGB18030CharsFromCodePoint(GBCP, @S[1]);

        Content.Add(IntToHex(GBCP, 2) + ' = ' + IntToHex(UCP, 2));
        Inc(Result);
      end;
    end;
    Inc(UCP);
  end;
end;

procedure TFormGB18030.btnUtf16CodePointToGB180301Click(Sender: TObject);
var
  GBCP, UCP: TCnCodePoint;
begin
  UCP := $2ECA;
  GBCP := GetGB18030FromUnicodeCodePoint(UCP);
  ShowMessage(IntToHex(GBCP, 2));
end;

procedure TFormGB18030.btnGenUnicodeGB18030Compare2Click(Sender: TObject);
var
  SL: TCnAnsiStringList;
begin
  SL := TCnAnsiStringList.Create;

  GenCn2Utf16ToGB18030Page(0, 0, $FF, $FF, SL);
  GenCn2Utf16ToGB18030Page(0, 0, $FF, $FF, SL, 1);
  GenCn2Utf16ToGB18030Page(0, 0, $FF, $FF, SL, 2);

  dlgSave1.FileName := 'UTF16_GB18030_gen.txt';
  if dlgSave1.Execute then
  begin
    SL.SaveToFile(dlgSave1.FileName);
    ShowMessage('Save to ' + dlgSave1.FileName);
  end;
  SL.Free;
end;

procedure TFormGB18030.GenCn2Utf16ToGB18030Page(FromH, FromL, ToH,
  ToL: Byte; Content: TCnAnsiStringList; H2: Word);
var
  H, L: Integer;
  GBCP, UCP: TCnCodePoint;
  S: AnsiString;
begin
  for H := FromH to ToH do
  begin
    for L := FromL to ToL do
    begin
      UCP := ((H shl 8) or L) + (H2 shl 16);
      GBCP := GetGB18030FromUnicodeCodePoint(UCP);
      if GBCP <> CN_INVALID_CODEPOINT then
      begin
        S := IntToHex(UCP, 2) + ' = ' + IntToHex(GBCP, 2);
      end
      else
        S := IntToHex(UCP, 2) + ' = ';

      Content.Add(S);
    end;
  end;
end;

procedure TFormGB18030.btnStringGB18030ToUnicodeClick(Sender: TObject);
var
  S: TCnGB18030String;
  W: WideString;
  L: Integer;
begin
  SetLength(S, 20);  // 1 1 1 2 4 2 4 1 4
  S[1] := 'A';
  S[2] := '3';
  S[3] := '.';

  S[4] := #$E0;
  S[5] := #$D3;      // Unicode $5624

  S[6] := #$81;
  S[7] := #$39;
  S[8] := #$EF;
  S[9] := #$34;      // Unicode $3405

  S[10] := #$C0;
  S[11] := #$D0;     // Unicode $4F6C

  S[12] := #$98;
  S[13] := #$32;
  S[14] := #$8D;
  S[15] := #$33;     // Unicode $29413 四字节编码为 $65D813DC

  S[16] := '_';

  S[17] := #$83;
  S[18] := #$36;
  S[19] := #$B1;
  S[20] := #$35;     // Unicode $D720

  L := GB18030ToUtf16(PCnGB18030StringPtr(S), nil);
  if L > 0 then
  begin
    SetLength(W, L);
    GB18030ToUtf16(PCnGB18030StringPtr(S), PWideChar(W));
    MessageBoxW(Handle, PWideChar(W), nil, MB_OK);
  end;
end;

end.
