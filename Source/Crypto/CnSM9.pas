{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     �й����Լ��Ŀ���Դ�������������                         }
{                   (C)Copyright 2001-2020 CnPack ������                       }
{                   ------------------------------------                       }
{                                                                              }
{            ���������ǿ�Դ���������������������� CnPack �ķ���Э������        }
{        �ĺ����·�����һ����                                                }
{                                                                              }
{            ������һ��������Ŀ����ϣ�������ã���û���κε���������û��        }
{        �ʺ��ض�Ŀ�Ķ������ĵ���������ϸ���������� CnPack ����Э�顣        }
{                                                                              }
{            ��Ӧ���Ѿ��Ϳ�����һ���յ�һ�� CnPack ����Э��ĸ��������        }
{        ��û�У��ɷ������ǵ���վ��                                            }
{                                                                              }
{            ��վ��ַ��http://www.cnpack.org                                   }
{            �����ʼ���master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnSM9;
{* |<PRE>
================================================================================
* �������ƣ�������������
* ��Ԫ���ƣ�SM9 ������Բ����˫����ӳ���������֤�㷨��Ԫ
* ��Ԫ���ߣ���Х
* ��    ע���ο��� GmSSL/PBC/Federico2014 Դ�롣
*           ���Ρ��ĴΡ�ʮ��������ֱ��� U V W �˷�������Ԫ�طֱ��� FP2��FP4��FP12 ��ʾ
*           G1 �� G2 Ⱥ����� TCnEccPoint �� TCnFP2Point ����ΪԪ������㣬���� X Y
*           ��������ϵ/�ſɱ�����ϵ�����Ԫ��Ҳ�мӡ��ˡ��󷴡�Frobenius �Ȳ���
*           ����������ʵ���˻��� SM9 �� BN ���߲����Ļ��� R-ate ����
*           ע�� Miller �㷨�Ƕ����� F(q^k) �����ϵ���Բ�����еģ����һ��Ԫ���� k ά����
*           Miller �㷨�������ʵ������ʲô��
* ����ƽ̨��Win7 + Delphi 5.0
* ���ݲ��ԣ���δ����
* �� �� �����õ�Ԫ���豾�ػ�����
* �޸ļ�¼��2020.04.04 V1.0
*               ������Ԫ��ʵ�ֹ���
================================================================================
|</PRE>}

interface

{$I CnPack.inc}

uses
  Classes, SysUtils, Consts, SysConst,
  CnContainers, CnBigNumber, CnECC, CnNativeDecl;

const
  // һ������ T����֪����ɶ���� SM9 ��ѡ��� BN �����
  // �����������׺͸��ޱ�����˹��̬ͬӳ��ļ����� T ��ָ���Ķ���ʽ����ʽ
  CN_SM9_T = '600000000058F98A';

  // SM9 ��Բ���߷��̵� A ϵ��ֵ
  CN_SM9_ECC_A = 0;

  // SM9 ��Բ���߷��̵� B ϵ��ֵ
  CN_SM9_ECC_B = 5;

  // SM9 ��Բ���ߵ�������Ҳ�л������������������ 36t^4 + 36t^3 + 24t^2 + 6t + 1��
  CN_SM9_FINITE_FIELD = 'B640000002A3A6F1D603AB4FF58EC74521F2934B1A7AEEDBE56F9B27E351457D';

  // SM9 ��Բ���ߵĽף�Ҳ�����ܵ�������������� 36t^4 + 36t^3 + 18t^2 + 6t + 1��
  // ��ò�ƽ� N��Ҫ���� cf ���ܽ� Order�������� cf = 1������ N �� Order �ȼۣ�
  CN_SM9_ORDER = 'B640000002A3A6F1D603AB4FF58EC74449F2934B18EA8BEEE56EE19CD69ECF25';

  // SM9 ��Բ���ߵ������ӣ����� N �͵õ���
  CN_SM9_CF = 1;

  // SM9 ��Բ���ߵ�Ƕ�������Ҳ���� Prime ����СǶ������η��� Order ��ģΪ 1
  CN_SM9_K = 12;

  // ���ޱ�����˹��̬ͬӳ��ļ���Ҳ���� Hasse �����е� ��=q+1-trace �е� trace
  // �� SM9 ��Բ�����е��� 6t^2 + 1
  CN_SM9_FROBENIUS_TRACE = 'D8000000019062ED0000B98B0CB27659';

  // G1 ����Ԫ�ĵ�����
  CN_SM9_G1_P1X = '93DE051D62BF718FF5ED0704487D01D6E1E4086909DC3280E8C4E4817C66DDDD';
  CN_SM9_G1_P1Y = '21FE8DDA4F21E607631065125C395BBC1C1C00CBFA6024350C464CD70A3EA616';

  // G2 ����Ԫ��˫����
  CN_SM9_G2_P2X0 = '3722755292130B08D2AAB97FD34EC120EE265948D19C17ABF9B7213BAF82D65B';
  CN_SM9_G2_P2X1 = '85AEF3D078640C98597B6027B441A01FF1DD2C190F5E93C454806C11D8806141';
  CN_SM9_G2_P2Y0 = 'A7CF28D519BE3DA65F3170153D278FF247EFBA98A71A08116215BBA5C999A7C7';
  CN_SM9_G2_P2Y1 = '17509B092E845C1266BA0D262CBEE6ED0736A96FA347C8BD856DC76B84EBEB96';

  // R-ate �Եļ����������ʵ���� 6T + 2
  CN_SM9_6T_PLUS_2 = '02400000000215D93E';

  CN_SM9_FAST_EXP_P3 = '5C5E452404034E2AF12FCAD3B31FE2B0D62CD8FB7B497A0ADC53E586930846F1' +
    'BA4CADE09029E4717C0CA02D9B0D8649A5782C82FDB6B0A10DA3D71BCDB13FE5E0D49DE3AA8A4748' +
    '83687EE0C6D9188C44BF9D0FA74DDFB7A9B2ADA593152855';

  CN_SM9_FAST_EXP_PW20 = 'F300000002A3A6F2780272354F8B78F4D5FC11967BE65334';
  CN_SM9_FAST_EXP_PW21 = 'B640000002A3A6F0E303AB4FF2EB2052A9F02115CAEF75E70F738991676AF249';
  CN_SM9_FAST_EXP_PW22 = 'F300000002A3A6F2780272354F8B78F4D5FC11967BE65333';
  CN_SM9_FAST_EXP_PW23 = 'B640000002A3A6F0E303AB4FF2EB2052A9F02115CAEF75E70F738991676AF24A';

type
  TCnFP2 = class
  {* �����������ϵ��Ԫ��ʵ����}
  private
    F0: TCnBigNumber;
    F1: TCnBigNumber;
    function GetItems(Index: Integer): TCnBigNumber;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    function IsZero: Boolean;
    function IsOne: Boolean;
    function SetZero: Boolean;
    function SetOne: Boolean;
    function SetU: Boolean;
    function SetBigNumber(const Num: TCnBigNumber): Boolean;
    function SetHex(const S0, S1: string): Boolean;
    function SetWord(Value: Cardinal): Boolean;
    function SetWords(Value0, Value1: Cardinal): Boolean;

    property Items[Index: Integer]: TCnBigNumber read GetItems; default;
  end;

  TCnFP2Pool = class(TCnMathObjectPool)
  {* �����������ϵ��Ԫ�س�ʵ���࣬����ʹ�õ������������ϵ��Ԫ�صĵط����д�����}
  protected
    function CreateObject: TObject; override;
  public
    function Obtain: TCnFP2; reintroduce;
    procedure Recycle(Num: TCnFP2); reintroduce;
  end;

  TCnFP4 = class
  {* �Ĵ��������ϵ��Ԫ��ʵ����}
  private
    F0: TCnFP2;
    F1: TCnFP2;
    function GetItems(Index: Integer): TCnFP2;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    function IsZero: Boolean;
    function IsOne: Boolean;
    function SetZero: Boolean;
    function SetOne: Boolean;
    function SetU: Boolean;
    function SetV: Boolean;
    function SetBigNumber(const Num: TCnBigNumber): Boolean;
    function SetBigNumbers(const Num0, Num1: TCnBigNumber): Boolean;
    function SetHex(const S0, S1, S2, S3: string): Boolean;
    function SetWord(Value: Cardinal): Boolean;
    function SetWords(Value0, Value1, Value2, Value3: Cardinal): Boolean;

    property Items[Index: Integer]: TCnFP2 read GetItems; default;
  end;

  TCnFP4Pool = class(TCnMathObjectPool)
  {* �Ĵ��������ϵ��Ԫ�س�ʵ���࣬����ʹ�õ��Ĵ��������ϵ��Ԫ�صĵط����д�����}
  protected
    function CreateObject: TObject; override;
  public
    function Obtain: TCnFP4; reintroduce;
    procedure Recycle(Num: TCnFP4); reintroduce;
  end;

  TCnFP12 = class
  {* ʮ�����������ϵ��Ԫ��ʵ����}
  private
    F0: TCnFP4;
    F1: TCnFP4;
    F2: TCnFP4;
    function GetItems(Index: Integer): TCnFP4;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    function IsZero: Boolean;
    function IsOne: Boolean;
    function SetZero: Boolean;
    function SetOne: Boolean;
    function SetU: Boolean;
    function SetV: Boolean;
    function SetW: Boolean;
    function SetWSqr: Boolean;
    function SetBigNumber(const Num: TCnBigNumber): Boolean;
    function SetBigNumbers(const Num0, Num1, Num2: TCnBigNumber): Boolean;
    function SetHex(const S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11: string): Boolean;
      
    function SetWord(Value: Cardinal): Boolean;
    function SetWords(Value0, Value1, Value2, Value3, Value4, Value5, Value6,
      Value7, Value8, Value9, Value10, Value11: Cardinal): Boolean;

    property Items[Index: Integer]: TCnFP4 read GetItems; default;
  end;

  TCnFP12Pool = class(TCnMathObjectPool)
  {* ʮ�����������ϵ��Ԫ�س�ʵ���࣬����ʹ�õ��Ĵ��������ϵ��Ԫ�صĵط����д�����}
  protected
    function CreateObject: TObject; override;
  public
    function Obtain: TCnFP12; reintroduce;
    procedure Recycle(Num: TCnFP12); reintroduce;
  end;

  TCnFP2Point = class(TPersistent)
  {* ��ͨ����ϵ��� FP2 ƽ��㣬������������ɣ����ﲻֱ�Ӳ�����㣬��ת���ɷ�������ϵ����}
  private
    FX: TCnFP2;
    FY: TCnFP2;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    {* ת��Ϊ�ַ���}
    property X: TCnFP2 read FX;
    property Y: TCnFP2 read FY;
  end;

  TCnFP2AffinePoint = class
  {* ��������ϵ��� FP2 ƽ��㣬�������������}
  private
    FX: TCnFP2;
    FY: TCnFP2;
    FZ: TCnFP2;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    {* ת��Ϊ�ַ���}
    procedure SetZero;
    {* ����Ϊȫ 0���ƺ�ûɶ��}
    function IsAtInfinity: Boolean;
    {* �Ƿ�λ������Զ��}
    function SetToInfinity: Boolean;
    {* ������Ϊ����Զ}
    function GetCoordinatesFP2(const FP2X, FP2Y: TCnFP2): Boolean;
    {* ��ȡ XY ����ֵ���ڲ����ø���}
    function SetCoordinatesFP2(const FP2X, FP2Y: TCnFP2): Boolean;
    {* ���� XY ����ֵ���ڲ����ø���}
    function SetCoordinatesHex(const SX0, SX1, SY0, SY1: string): Boolean;
    {* ���� XY ����ֵ��ʹ��ʮ�������ַ���}
    function SetCoordinatesBigNumbers(const X0, X1, Y0, Y1: TCnBigNumber): Boolean;
    {* ���� XY ����ֵ��ʹ�ô��������ڲ����ø���}
    function GetJacobianCoordinatesFP12(const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
    {* ��ȡ��չ XY ����ֵ���ڲ����ø���}
    function SetJacobianCoordinatesFP12(const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
    {* ������չ XY ����ֵ���ڲ����ø���}
    function IsOnCurve(Prime: TCnBigNumber): Boolean;
    {* �ж��Ƿ�����Բ���� y^2 = x^3 + 5 ��}

    property X: TCnFP2 read FX;
    property Y: TCnFP2 read FY;
    property Z: TCnFP2 read FZ;
  end;

  TCnFP2AffinePointPool = class(TCnMathObjectPool)
  {* ��������ϵ���ƽ����ʵ���࣬����ʹ�õ���������ϵ���ƽ���ĵط����д�����}
  protected
    function CreateObject: TObject; override;
  public
    function Obtain: TCnFP2AffinePoint; reintroduce;
    procedure Recycle(Num: TCnFP2AffinePoint); reintroduce;
  end;

// ============================ SM9 ����ʵ���� =================================

  TCnSM9SignatureMasterPrivateKey = TCnBigNumber;
  {* SM9 �е�ǩ����˽Կ���������}
  TCnSM9SignatureMasterPublicKey  = TCnFP2Point;
  {* SM9 �е�ǩ������Կ����ǩ����˽Կ���� G2 �����}

  TCnSM9SignatureMasterKey = class
  {* SM9 �е�ǩ������Կ���� KGC ��Կ�����������ɣ���Կ�ɹ���}
  private
    FPrivateKey: TCnSM9SignatureMasterPrivateKey;
    FPublicKey: TCnSM9SignatureMasterPublicKey;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property PrivateKey: TCnSM9SignatureMasterPrivateKey read FPrivateKey;
    property PublicKey: TCnSM9SignatureMasterPublicKey read FPublicKey;
  end;

  TCnSM9SignatureUserPrivateKey = TCnFP2;
  {* SM9 �е��û�ǩ��˽Կ���� KGC ��Կ�������ĸ����û���ʶ���ɣ��޶�Ӧ��Կ
    ����˵���û���֤ǩ��ʱ�õĹ�Կ�����û���ʶ��ǩ������Կ}

  TCnSm9EncryptionMasterPrivateKey = TCnBigNumber;
  {* SM9 �еļ�����˽Կ���������}

  TCnSm9EncryptionMasterPublicKey = TCnEccPoint;
  {* SM9 �еļ�������Կ���ü�����˽Կ���� G1 �����}

  TCnSM9EncryptionMasterKey = class
  {* SM9 �еļ�������Կ���� KGC ��Կ�����������ɣ���Կ�ɹ���}
  private
    FPrivateKey: TCnSM9EncryptionMasterPrivateKey;
    FPublicKey: TCnSM9EncryptionMasterPublicKey;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property PrivateKey: TCnSM9EncryptionMasterPrivateKey read FPrivateKey;
    property PublicKey: TCnSM9EncryptionMasterPublicKey read FPublicKey;
  end;

  TCnSM9EncryptionUserPrivateKey = TCnFP4;
  {* SM9 �е��û�����˽Կ���� KGC ��Կ�������ĸ����û���ʶ���ɣ��޶�Ӧ��Կ
    ����˵���û�����ʱ�õĹ�Կ�����û���ʶ���������Կ}

  TCnSM9 = class(TCnEcc)
  private
    FGenerator2: TCnFP2Point;

  public
    constructor Create; reintroduce;
    destructor Destroy; override;

    property Generator2: TCnFP2Point read FGenerator2;
  end;

// ====================== �����������ϵ��Ԫ�����㺯�� =========================

function FP2New: TCnFP2;
{* ����һ�����������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP2.Create}

procedure FP2Free(FP2: TCnFP2);
{* �ͷ�һ�����������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP2.Free}

function FP2IsZero(FP2: TCnFP2): Boolean;
{* �ж�һ�����������ϵ��Ԫ�ض����Ƿ�Ϊ 0}

function FP2IsOne(FP2: TCnFP2): Boolean;
{* �ж�һ�����������ϵ��Ԫ�ض����Ƿ�Ϊ 1}

function FP2SetZero(FP2: TCnFP2): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊ 0}

function FP2SetOne(FP2: TCnFP2): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊ 1��Ҳ���� [0] Ϊ 1��[1] Ϊ 0}

function FP2SetU(FP2: TCnFP2): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�����Ϊ U��Ҳ���� [0] Ϊ 0��[1] Ϊ 1}

function FP2SetBigNumber(const FP2: TCnFP2; const Num: TCnBigNumber): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊĳһ������}

function FP2SetBigNumbers(const FP2: TCnFP2; const Num0, Num1: TCnBigNumber): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊ��������ֵ}

function FP2SetHex(const FP2: TCnFP2; const S0, S1: string): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊ����ʮ�������ַ���}

function FP2ToString(const FP2: TCnFP2): string;
{* ��һ�����������ϵ��Ԫ�ض���ת��Ϊ�ַ���}

function FP2SetWord(const FP2: TCnFP2; Value: Cardinal): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊһ�� Cardinal}

function FP2SetWords(const FP2: TCnFP2; Value0, Value1: Cardinal): Boolean;
{* ��һ�����������ϵ��Ԫ�ض�������Ϊ���� Cardinal}

function FP2Equal(const F1, F2: TCnFP2): Boolean;
{* �ж����������������ϵ��Ԫ�ض���ֵ�Ƿ����}

function FP2Copy(const Dst, Src: TCnFP2): TCnFP2;
{* ��һ�����������ϵ��Ԫ�ض���ֵ���Ƶ���һ�������������ϵ��Ԫ�ض�����}

function FP2Negate(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
{* ��һ�����������ϵ��Ԫ�ض���ֵ����������}

function FP2Add(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ�ؼӷ���Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP2Sub(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ�ؼ�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP2Mul(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean; overload;
{* �������ж����������ϵ��Ԫ�س˷���Prime Ϊ��������Res �������� F1 �� F2��F1 ������ F2}

function FP2Mul3(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ�ض������ 3��Prime Ϊ��������Res ������ F}

function FP2MulU(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ�� U �˷���Prime Ϊ��������Res �������� F1 �� F2��F1 ������ F2}

function FP2Mul(const Res: TCnFP2; const F: TCnFP2; Num: TCnBigNumber; Prime: TCnBigNumber): Boolean; overload;
{* �������ж����������ϵ��Ԫ��������ĳ˷���Prime Ϊ��������Res ������ F���� Num ������ Res �� F �е�����}

function FP2Inverse(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ����ģ����Prime Ϊ��������Res ������ F}

function FP2Div(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
{* �������ж����������ϵ��Ԫ�س�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2���ڲ���ģ���˷�ʵ��}

function FP2ToStream(FP2: TCnFP2; Stream: TStream): Integer;
{* ��һ�����������ϵ��Ԫ�ض��������д����������д�볤��}

// ====================== �Ĵ��������ϵ��Ԫ�����㺯�� =========================

function FP4New: TCnFP4;
{* ����һ�Ĵ��������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP4.Create}

procedure FP4Free(FP4: TCnFP4);
{* �ͷ�һ�Ĵ��������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP4.Free}

function FP4IsZero(FP4: TCnFP4): Boolean;
{* �ж�һ�Ĵ��������ϵ��Ԫ�ض����Ƿ�Ϊ 0}

function FP4IsOne(FP4: TCnFP4): Boolean;
{* �ж�һ�Ĵ��������ϵ��Ԫ�ض����Ƿ�Ϊ 1}

function FP4SetZero(FP4: TCnFP4): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ 0}

function FP4SetOne(FP4: TCnFP4): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ 1��Ҳ���� [0] Ϊ 1��[1] Ϊ 0}

function FP4SetU(FP4: TCnFP4): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�����Ϊ U��Ҳ���� [0] Ϊ U��[1] Ϊ 0}

function FP4SetV(FP4: TCnFP4): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�����Ϊ V��Ҳ���� [0] Ϊ 0��[1] Ϊ 1}

function FP4SetBigNumber(const FP4: TCnFP4; const Num: TCnBigNumber): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊĳһ������}

function FP4SetBigNumbers(const FP4: TCnFP4; const Num0, Num1: TCnBigNumber): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ��������ֵ}

function FP4SetFP2(const FP4: TCnFP4; const FP2: TCnFP2): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊһ�������������ϵ��Ԫ��}

function FP4Set2FP2S(const FP4: TCnFP4; const FP20, FP21: TCnFP2): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ���������������ϵ��Ԫ��}

function FP4SetHex(const FP4: TCnFP4; const S0, S1, S2, S3: string): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ�ĸ�ʮ�������ַ���}

function FP4ToString(const FP4: TCnFP4): string;
{* ��һ�Ĵ��������ϵ��Ԫ�ض���ת��Ϊ�ַ���}

function FP4SetWord(const FP4: TCnFP4; Value: Cardinal): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊһ�� Cardinal}

function FP4SetWords(const FP4: TCnFP4; Value0, Value1, Value2, Value3: Cardinal): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض�������Ϊ�ĸ� Cardinal}

function FP4Equal(const F1, F2: TCnFP4): Boolean;
{* �ж������Ĵ��������ϵ��Ԫ�ض���ֵ�Ƿ����}

function FP4Copy(const Dst, Src: TCnFP4): TCnFP4;
{* ��һ�Ĵ��������ϵ��Ԫ�ض���ֵ���Ƶ���һ���Ĵ��������ϵ��Ԫ�ض�����}

function FP4Negate(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ��һ�Ĵ��������ϵ��Ԫ�ض���ֵ����������}

function FP4Add(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�ؼӷ���Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP4Sub(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�ؼ�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP4Mul(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�س˷���Prime Ϊ��������Res �������� F1 �� F2��F1 ������ F2}

function FP4Mul3(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�ض������ 3��Prime Ϊ��������Res ������ F}

function FP4MulV(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�� V �˷���Prime Ϊ��������Res �������� F1 �� F2��F1 ������ F2}

function FP4Inverse(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ����ģ����Prime Ϊ��������Res ������ F}

function FP4Div(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
{* ���������Ĵ��������ϵ��Ԫ�س�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2���ڲ���ģ���˷�ʵ��}

function FP4ToStream(FP4: TCnFP4; Stream: TStream): Integer;
{* ��һ�Ĵ��������ϵ��Ԫ�ض��������д����������д�볤��}

// ===================== ʮ�����������ϵ��Ԫ�����㺯�� ========================

function FP12New: TCnFP12;
{* ����һʮ�����������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP12.Create}

procedure FP12Free(FP12: TCnFP12);
{* �ͷ�һʮ�����������ϵ��Ԫ�ض��󣬵�ͬ�� TCnFP12.Free}

function FP12IsZero(FP12: TCnFP12): Boolean;
{* �ж�һʮ�����������ϵ��Ԫ�ض����Ƿ�Ϊ 0}

function FP12IsOne(FP12: TCnFP12): Boolean;
{* �ж�һʮ�����������ϵ��Ԫ�ض����Ƿ�Ϊ 1}

function FP12SetZero(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊ 0}

function FP12SetOne(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊ 1}

function FP12SetU(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�����Ϊ U��Ҳ������ FP4 �ֱ� U��0��0}

function FP12SetV(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�����Ϊ V��Ҳ������ FP4 �ֱ� V��0��0}

function FP12SetW(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�����Ϊ W��Ҳ������ FP4 �ֱ� 0��1��0}

function FP12SetWSqr(FP12: TCnFP12): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�����Ϊ W^2��Ҳ������ FP4 �ֱ� 0��0��1}

function FP12SetBigNumber(const FP12: TCnFP12; const Num: TCnBigNumber): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊĳһ������}

function FP12SetBigNumbers(const FP12: TCnFP12; const Num0, Num1, Num2: TCnBigNumber): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊ��������ֵ}

function FP12SetFP4(const FP12: TCnFP12; const FP4: TCnFP4): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊһ���Ĵ��������ϵ��Ԫ��}

function FP12Set3FP4S(const FP12: TCnFP12; const FP40, FP41, FP42: TCnFP4): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊ�����Ĵ��������ϵ��Ԫ��}

function FP12SetFP2(const FP12: TCnFP12; const FP2: TCnFP2): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊһ�������������ϵ��Ԫ��}

function FP12SetHex(const FP12: TCnFP12; const S0, S1, S2, S3, S4, S5, S6, S7, S8,
  S9, S10, S11: string): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊʮ����ʮ�������ַ���}

function FP12ToString(const FP12: TCnFP12): string;
{* ��һʮ�����������ϵ��Ԫ�ض���ת��Ϊ�ַ���}

function FP12SetWord(const FP12: TCnFP12; Value: Cardinal): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊһ�� Cardinal}

function FP12SetWords(const FP12: TCnFP12; Value0, Value1, Value2, Value3, Value4,
  Value5, Value6, Value7, Value8, Value9, Value10, Value11: Cardinal): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض�������Ϊʮ���� Cardinal}

function FP12Equal(const F1, F2: TCnFP12): Boolean;
{* �ж�����ʮ�����������ϵ��Ԫ�ض���ֵ�Ƿ����}

function FP12Copy(const Dst, Src: TCnFP12): TCnFP12;
{* ��һʮ�����������ϵ��Ԫ�ض���ֵ���Ƶ���һ��ʮ�����������ϵ��Ԫ�ض�����}

function FP12Negate(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��һʮ�����������ϵ��Ԫ�ض���ֵ����������}

function FP12Add(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�ؼӷ���Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP12Sub(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�ؼ�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2}

function FP12Mul(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�س˷���Prime Ϊ��������Res �������� F1 �� F2��F1 ������ F2}

function FP12Mul3(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�ض������ 3��Prime Ϊ��������Res ������ F}

function FP12Inverse(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ����ģ����Prime Ϊ��������Res ������ F}

function FP12Div(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�س�����Prime Ϊ��������Res ������ F1��F2��F1 ������ F2���ڲ���ģ���˷�ʵ��}

function FP12Power(const Res: TCnFP12; const F: TCnFP12; Exponent: TCnBigNumber; Prime: TCnBigNumber): Boolean;
{* ��������ʮ�����������ϵ��Ԫ�س˷���Prime Ϊ��������Res ������ F����δ����}

function FP12ToStream(FP12: TCnFP12; Stream: TStream): Integer;
{* ��һʮ�����������ϵ��Ԫ�ض��������д����������д�볤��}

// ===================== ��������ϵ�����Ԫ������㺯�� ========================

function FP2AffinePointNew: TCnFP2AffinePoint;
{* ����һ��������ϵ�����Ԫ����󣬵�ͬ�� TCnAffinePoint.Create}

procedure AffinePointFree(P: TCnFP2AffinePoint);
{* �ͷ�һ��������ϵ�����Ԫ����󣬵�ͬ�� TCnAffinePoint.Free}

function FP2AffinePointSetZero(P: TCnFP2AffinePoint): Boolean;
{* ��һ����������ϵ�����Ԫ����������Ϊȫ 0}

function FP2AffinePointToString(const P: TCnFP2AffinePoint): string;
{* ��һ��������ϵ�����Ԫ�����ת��Ϊ�ַ���}

function FP2AffinePointEqual(const P1, P2: TCnFP2AffinePoint): Boolean;
{* �ж�������������ϵ�����Ԫ�����ֵ�Ƿ����}

function FP2AffinePointCopy(const Dst, Src: TCnFP2AffinePoint): TCnFP2AffinePoint;
{* ��һ��������ϵ�����Ԫ�����ֵ���Ƶ���һ����������ϵ�����Ԫ�������}

function FP2AffinePointIsAtInfinity(const P: TCnFP2AffinePoint): Boolean;
{* �ж�һ��������ϵ�����Ԫ������Ƿ�λ������Զ��}

function FP2AffinePointSetToInfinity(const P: TCnFP2AffinePoint): Boolean;
{* ��һ��������ϵ�����Ԫ�����������Ϊ����Զ}

function FP2AffinePointGetCoordinates(const P: TCnFP2AffinePoint; const FP2X, FP2Y: TCnFP2): Boolean;
{* ��ȡһ��������ϵ�����Ԫ������ XY ����ֵ���ڲ����ø���}

function FP2AffinePointSetCoordinates(const P: TCnFP2AffinePoint; const FP2X, FP2Y: TCnFP2): Boolean;
{* ����һ��������ϵ�����Ԫ������ XY ����ֵ���ڲ����ø���}

function FP2AffinePointSetCoordinatesHex(const P: TCnFP2AffinePoint;
  const SX0, SX1, SY0, SY1: string): Boolean;
{* ����һ��������ϵ�����Ԫ������ XY ����ֵ��ʹ��ʮ�������ַ���}

function FP2AffinePointSetCoordinatesBigNumbers(const P: TCnFP2AffinePoint;
  const X0, X1, Y0, Y1: TCnBigNumber): Boolean;
{* ����һ��������ϵ�����Ԫ������ XY ����ֵ��ʹ�ô��������ڲ����ø���}

function FP2AffinePointGetJacobianCoordinates(const P: TCnFP2AffinePoint;
  const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ��ȡһ��������ϵ�����Ԫ�������ſɱ� XY ����ֵ���ڲ����ø���}

function FP2AffinePointSetJacobianCoordinates(const P: TCnFP2AffinePoint;
  const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
{* ����һ��������ϵ�����Ԫ�������ſɱ� XY ����ֵ���ڲ����ø���}

function FP2AffinePointIsOnCurve(const P: TCnFP2AffinePoint; Prime: TCnBigNumber): Boolean;
{* �ж�һ��������ϵ�����Ԫ������Ƿ�����Բ���� y^2 = x^3 + 5 ��}

function FP2AffinePointNegate(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* һ����������ϵ�����Ԫ��������Բ�����󷴣�Res ������ P}

function FP2AffinePointDouble(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* һ����������ϵ�����Ԫ��������Բ���߱��㷨��Res ������ P}

function FP2AffinePointAdd(const Res: TCnFP2AffinePoint; const P, Q: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* ������������ϵ�����Ԫ��������Բ���߼ӷ���Res ������ P �� Q��P ������ Q��
  ע���ڲ����ǽ� Z ���� 1����Ȼ���󷴵���ͨ����}

function FP2AffinePointSub(const Res: TCnFP2AffinePoint; const P, Q: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* ������������ϵ�����Ԫ��������Բ���߼�����Res ������ P �� Q��P ������ Q}

function FP2AffinePointMul(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Num: TCnBigNumber; Prime: TCnBigNumber): Boolean;
{* һ����������ϵ�����Ԫ��������Բ���� N ���㷨��Res ������ P}

function FP2AffinePointFrobenius(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* ����һ����������ϵ�����Ԫ�����ĸ��ޱ�����˹��ֵ̬ͬ��Res ������ P
  ��ʵ���� P �� Prime �η��Ľ�� mod Prime}

function FP2PointToString(const P: TCnFP2Point): string;
{* ��һ��������ϵ��Ķ�Ԫ�� FP2 ����ת��Ϊ�ַ���}

function FP2AffinePointToFP2Point(FP2P: TCnFP2Point; FP2AP: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
{* ��һ��������ϵ�����Ԫ�� FP2 ����ת��Ϊ��ͨ����ϵ��Ķ�Ԫ�� FP2 ����}

function FP2PointToFP2AffinePoint(FP2AP: TCnFP2AffinePoint; FP2P: TCnFP2Point): Boolean;
{* ��һ��������ϵ�����Ԫ�� FP2 ����ת��Ϊ��ͨ����ϵ��Ķ�Ԫ�� FP2 ����}

// ============================ ˫���ԶԼ��㺯�� ===============================

function Rate(const F: TCnFP12; const Q: TCnFP2AffinePoint; const XP, YP: TCnBigNumber;
  const A: TCnBigNumber; const K: TCnBigNumber; Prime: TCnBigNumber): Boolean;
{* ���� R-ate �ԡ������һ�� FP12 ֵ��������һ�� BN �����ϵĵ������ XP��YP��
  һ�� FP2 �ϵ� XYZ ��������㣬һ��ָ�� K��һ��ѭ������ A}

function SM9RatePairing(const F: TCnFP12; const Q: TCnFP2AffinePoint; const P: TCnEccPoint): Boolean;
{* ���� SM9 ָ���� BN ���ߵĲ����Լ�ָ������� R-ate �ԣ�����Ϊһ�� BN �����ϵĵ�
  һ�� FP2 �ϵ� XYZ ��������㣬���Ϊһ�� FP12 ֵ}

// =========================== SM9 ����ʵ�ֺ��� ================================

function CnSM9KGCGenerateSignatureMasterKey(SignatureMasterKey:
  TCnSM9SignatureMasterKey; SM9: TCnSM9 = nil): Boolean;
{* �� KCG ���ã�����ǩ������Կ}

function CnSM9KGCGenerateEncryptionMasterKey(EncryptionMasterKey:
  TCnSM9EncryptionMasterKey; SM9: TCnSM9 = nil): Boolean;
{* �� KCG ���ã����ɼ�������Կ}

function CnSM9KGCGenerateSignatureUserKey(SignatureMasterPrivateKey:
  TCnSM9SignatureMasterPrivateKey; const AUserID: AnsiString;
  OutSignatureUserKey: TCnSM9SignatureUserPrivateKey; SM9: TCnSM9 = nil): Boolean;
{* �� KCG ���ã������û� ID �����û�ǩ��˽Կ}

function CnSM9KGCGenerateEncryptionUserKey(EncryptionMasterKey:
  TCnSM9EncryptionUserPrivateKey; const AUserID: AnsiString;
  OutEncryptionUserKey: TCnSM9EncryptionUserPrivateKey; SM9: TCnSM9 = nil): Boolean;
{* �� KCG ���ã������û� ID �����û�����˽Կ}

function CnSM9Hash1(const Res: TCnBigNumber; Data: Pointer; DataLen: Integer;
  N: TCnBigNumber): Boolean;
{* SM9 �й涨�ĵ�һ�����뺯�����ڲ�ʹ�� SM3��256 λ��ɢ�к���
  ����Ϊ���ش� Data ����� N�����Ϊ 1 �� N - 1 �������ڵĴ�����N Ӧ�ô� SM9.Order}

function CnSM9Hash2(const Res: TCnBigNumber; Data: Pointer; DataLen: Integer;
  N: TCnBigNumber): Boolean;
{* SM9 �й涨�ĵڶ������뺯�����ڲ�ʹ�� SM3��256 λ��ɢ�к���
  ����Ϊ���ش� Data ����� N�����Ϊ 1 �� N - 1 �������ڵĴ�����N Ӧ�ô� SM9.Order}

implementation

uses
  CnSM3;

const
  CRLF = #13#10;

  CN_SM9_HASH_PREFIX_1 = 1;
  CN_SM9_HASH_PREFIX_2 = 2;

  CN_SM3_DIGEST_BITS = SizeOf(TSM3Digest) * 8;

var
  FLocalBigNumberPool: TCnBigNumberPool = nil;
  FLocalFP2Pool: TCnFP2Pool = nil;
  FLocalFP4Pool: TCnFP4Pool = nil;
  FLocalFP12Pool: TCnFP12Pool = nil;
  FLocalFP2AffinePointPool: TCnFP2AffinePointPool = nil;

  // SM9 �������س���
  FSM9FiniteFieldSize: TCnBigNumber = nil;
  FSM9Order: TCnBigNumber = nil;
  FSM9K: Integer = 12;
  FSM9G1P1X: TCnBigNumber = nil;
  FSM9G1P1Y: TCnBigNumber = nil;
  FSM9G2P2X0: TCnBigNumber = nil;
  FSM9G2P2X1: TCnBigNumber = nil;
  FSM9G2P2Y0: TCnBigNumber = nil;
  FSM9G2P2Y1: TCnBigNumber = nil;
  FSM96TPlus2: TCnBigNumber = nil;
  FSM9FastExpP3: TCnBigNumber = nil;
  FFP12FastExpPW20: TCnBigNumber = nil;
  FFP12FastExpPW21: TCnBigNumber = nil;
  FFP12FastExpPW22: TCnBigNumber = nil;
  FFP12FastExpPW23: TCnBigNumber = nil;

// ====================== �����������ϵ��Ԫ�����㺯�� =========================

function FP2New: TCnFP2;
begin
  Result := TCnFP2.Create;
end;

procedure FP2Free(FP2: TCnFP2);
begin
  FP2.Free;
end;

function FP2IsZero(FP2: TCnFP2): Boolean;
begin
  Result := FP2[0].IsZero and FP2[1].IsZero;
end;

function FP2IsOne(FP2: TCnFP2): Boolean;
begin
  Result := FP2[0].IsOne and FP2[1].IsZero;
end;

function FP2SetZero(FP2: TCnFP2): Boolean;
begin
  Result := False;
  if not FP2[0].SetZero then Exit;
  if not FP2[1].SetZero then Exit;
  Result := True;
end;

function FP2SetOne(FP2: TCnFP2): Boolean;
begin
  Result := False;
  if not FP2[0].SetOne then Exit;
  if not FP2[1].SetZero then Exit;
  Result := True;
end;

function FP2SetU(FP2: TCnFP2): Boolean;
begin
  Result := False;
  if not FP2[0].SetZero then Exit;
  if not FP2[1].SetOne then Exit;
  Result := True;
end;

function FP2SetBigNumber(const FP2: TCnFP2; const Num: TCnBigNumber): Boolean;
begin
  Result := False;
  if BigNumberCopy(FP2[0], Num) = nil then Exit;
  if not FP2[1].SetZero then Exit;
  Result := True;
end;

function FP2SetBigNumbers(const FP2: TCnFP2; const Num0, Num1: TCnBigNumber): Boolean;
begin
  Result := False;
  if BigNumberCopy(FP2[0], Num0) = nil then Exit;
  if BigNumberCopy(FP2[1], Num1) = nil then Exit;
  Result := True;
end;

function FP2SetHex(const FP2: TCnFP2; const S0, S1: string): Boolean;
begin
  Result := False;
  if not FP2[0].SetHex(S0) then Exit;
  if not FP2[1].SetHex(S1) then Exit;
  Result := True;
end;

function FP2ToString(const FP2: TCnFP2): string;
begin
  Result := FP2[1].ToHex + ',' + FP2[0].ToHex;
end;

function FP2SetWord(const FP2: TCnFP2; Value: Cardinal): Boolean;
begin
  Result := False;
  if not FP2[0].SetWord(Value) then Exit;
  if not FP2[1].SetZero then Exit;
  Result := True;
end;

function FP2SetWords(const FP2: TCnFP2; Value0, Value1: Cardinal): Boolean;
begin
  Result := False;
  if not FP2[0].SetWord(Value0) then Exit;
  if not FP2[1].SetWord(Value1) then Exit;
  Result := True;
end;

function FP2Equal(const F1, F2: TCnFP2): Boolean;
begin
  Result := BigNumberEqual(F1[0], F2[0]) and BigNumberEqual(F1[1], F2[1]);
end;

function FP2Copy(const Dst, Src: TCnFP2): TCnFP2;
begin
  Result := nil;
  if BigNumberCopy(Dst[0], Src[0]) = nil then Exit;
  if BigNumberCopy(Dst[1], Src[1]) = nil then Exit;
  Result := Dst;
end;

function FP2Negate(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not BigNumberSub(Res[0], Prime, F[0]) then Exit;
  if not BigNumberSub(Res[1], Prime, F[1]) then Exit;
  if not BigNumberNonNegativeMod(Res[0], Res[0], Prime) then Exit;
  if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
  Result := True;
end;

function FP2Add(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not BigNumberAdd(Res[0], F1[0], F2[0]) then Exit;
  if not BigNumberAdd(Res[1], F1[1], F2[1]) then Exit;
  if not BigNumberNonNegativeMod(Res[0], Res[0], Prime) then Exit;
  if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
  Result := True;
end;

function FP2Sub(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not BigNumberSub(Res[0], F1[0], F2[0]) then Exit;
  if not BigNumberSub(Res[1], F1[1], F2[1]) then Exit;
  if not BigNumberNonNegativeMod(Res[0], Res[0], Prime) then Exit;
  if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
  Result := True;
end;

function FP2Mul(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
var
  T0, T1, R0: TCnBigNumber;
begin
  Result := False;

  // r0 = a0 * b0 - 2 * a1 * b1
  // r1 = a0 * b1 + a1 * b0
  T0 := nil;
  T1 := nil;
  R0 := nil;

  try
    T0 := FLocalBigNumberPool.Obtain;
    T1 := FLocalBigNumberPool.Obtain;
    R0 := FLocalBigNumberPool.Obtain;

    if not BigNumberMul(T0, F1[0], F2[0]) then Exit;
    if not BigNumberMul(T1, F1[1], F2[1]) then Exit;
    if not BigNumberAdd(T1, T1, T1) then Exit;
    if not BigNumberSub(T0, T0, T1) then Exit;
    if not BigNumberNonNegativeMod(R0, T0, Prime) then Exit; // ����ֱ�Ӹ� Res[0] ��ֵ����һ F1 �� Res ��ͬ�����ǰӰ�� F0

    if not BigNumberMul(T0, F1[0], F2[1]) then Exit;
    if not BigNumberMul(T1, F1[1], F2[0]) then Exit;
    if not BigNumberAdd(T1, T0, T1) then Exit;
    if not BigNumberNonNegativeMod(Res[1], T1, Prime) then Exit;

    if BigNumberCopy(Res[0], R0) = nil then Exit;
    Result := True;
  finally
    FLocalBigNumberPool.Recycle(R0);
    FLocalBigNumberPool.Recycle(T1);
    FLocalBigNumberPool.Recycle(T0);
  end;
end;

function FP2Mul3(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
var
  T: TCnFP2;
begin
  Result := False;
  T := FLocalFP2Pool.Obtain;
  try
    if not FP2Add(T, F, F, Prime) then Exit;
    if not FP2Add(Res, T, F, Prime) then Exit;
    Result := True;
  finally
    FLocalFP2Pool.Recycle(T);
  end;
end;

function FP2MulU(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
var
  T0, T1: TCnBigNumber;
begin
  Result := False;

  // r0 = -2 * (a0 * b1 + a1 * b0)
  // r1 = a0 * b0 - 2 * a1 * b1
  T0 := nil;
  T1 := nil;
  try
    T0 := FLocalBigNumberPool.Obtain;
    T1 := FLocalBigNumberPool.Obtain;

    if not BigNumberMul(T0, F1[0], F2[1]) then Exit;
    if not BigNumberMul(T1, F1[1], F2[0]) then Exit;
    if not BigNumberAdd(T0, T0, T1) then Exit;
    if not T0.MulWord(2) then Exit;
    T0.Negate;
    if not BigNumberNonNegativeMod(Res[0], T0, Prime) then Exit;

    if not BigNumberMul(T0, F1[0], F2[0]) then Exit;
    if not BigNumberMul(T1, F1[1], F2[1]) then Exit;
    if not T1.MulWord(2) then Exit;
    if not BigNumberSub(T1, T0, T1) then Exit;
    if not BigNumberNonNegativeMod(Res[1], T1, Prime) then Exit;
    Result := True;
  finally
    FLocalBigNumberPool.Recycle(T1);
    FLocalBigNumberPool.Recycle(T0);
  end;
end;

function FP2Mul(const Res: TCnFP2; const F: TCnFP2; Num: TCnBigNumber; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not BigNumberMul(Res[0], F[0], Num) then Exit;
  if not BigNumberMul(Res[1], F[1], Num) then Exit;
  if not BigNumberNonNegativeMod(Res[0], Res[0], Prime) then Exit;
  if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
  Result := True;
end;

function FP2Inverse(const Res: TCnFP2; const F: TCnFP2; Prime: TCnBigNumber): Boolean;
var
  K, T: TCnBigNumber;
begin
  Result := False;
  if F[0].IsZero then
  begin
    if not Res[0].SetZero then Exit;
    // r1 = -((2 * a1)^-1) */
    if not BigNumberAdd(Res[1], F[1], F[1]) then Exit;
    BigNumberModularInverse(Res[1], Res[1], Prime);
    if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
    if not BigNumberSub(Res[1], Prime, Res[1]) then Exit;
    Result := True;
  end
  else if F[1].IsZero then
  begin
    if not Res[1].SetZero then Exit;
    // r0 = a0^-1
    BigNumberModularInverse(Res[0], F[0], Prime);
    Result := True;
  end
  else
  begin
    // k = (a[0]^2 + 2 * a[1]^2)^-1
    // r[0] = a[0] * k
    // r[1] = -a[1] * k
    K := nil;
    T := nil;
    try
      K := FLocalBigNumberPool.Obtain;
      T := FLocalBigNumberPool.Obtain;

      if not BigNumberMul(T, F[1], F[1]) then Exit;
      if not T.MulWord(2) then Exit;
      if not BigNumberMul(K, F[0], F[0]) then Exit;
      if not BigNumberAdd(K, T, K) then Exit;
      BigNumberModularInverse(K, K, Prime);

      if not BigNumberMul(Res[0], F[0], K) then Exit;
      if not BigNumberNonNegativeMod(Res[0], Res[0], Prime) then Exit;

      if not BigNumberMul(Res[1], F[1], K) then Exit;
      if not BigNumberNonNegativeMod(Res[1], Res[1], Prime) then Exit;
      if not BigNumberSub(Res[1], Prime, Res[1]) then Exit;
      Result := True;
    finally
      FLocalBigNumberPool.Recycle(T);
      FLocalBigNumberPool.Recycle(K);
    end;
  end;
end;

function FP2Div(const Res: TCnFP2; const F1, F2: TCnFP2; Prime: TCnBigNumber): Boolean;
var
  Inv: TCnFP2;
begin
  Result := False;
  if F2.IsZero then
    raise EZeroDivide.Create(SDivByZero);

  if F1 = F2 then
  begin
    if not Res.SetOne then Exit;
    Result := True;
  end
  else
  begin
    Inv := FLocalFP2Pool.Obtain;
    try
      if not FP2Inverse(Inv, F2, Prime) then Exit;
      if not FP2Mul(Res, F1, Inv, Prime) then Exit;
      Result := True;
    finally
      FLocalFP2Pool.Recycle(Inv);
    end;
  end;
end;

function FP2ToStream(FP2: TCnFP2; Stream: TStream): Integer;
begin
  Result := BigNumberWriteBinaryToStream(FP2[0], Stream) + BigNumberWriteBinaryToStream(FP2[1], Stream);
end;

// ====================== �Ĵ��������ϵ��Ԫ�����㺯�� =========================

function FP4New: TCnFP4;
begin
  Result := TCnFP4.Create;
end;

procedure FP4Free(FP4: TCnFP4);
begin
  FP4.Free;
end;

function FP4IsZero(FP4: TCnFP4): Boolean;
begin
  Result := FP4[0].IsZero and FP4[1].IsZero;
end;

function FP4IsOne(FP4: TCnFP4): Boolean;
begin
  Result := FP4[0].IsOne and FP4[1].IsZero;
end;

function FP4SetZero(FP4: TCnFP4): Boolean;
begin
  Result := False;
  if not FP4[0].SetZero then Exit;
  if not FP4[1].SetZero then Exit;
  Result := True;
end;

function FP4SetOne(FP4: TCnFP4): Boolean;
begin
  Result := False;
  if not FP4[1].SetZero then Exit;
  if not FP4[0].SetOne then Exit;
  Result := True;
end;

function FP4SetU(FP4: TCnFP4): Boolean;
begin
  Result := False;
  if not FP4[1].SetZero then Exit;
  if not FP4[0].SetU then Exit;
  Result := True;
end;

function FP4SetV(FP4: TCnFP4): Boolean;
begin
  Result := False;
  if not FP4[0].SetZero then Exit;
  if not FP4[1].SetOne then Exit;
  Result := True;
end;

function FP4SetBigNumber(const FP4: TCnFP4; const Num: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP4[1].SetZero then Exit;
  if not FP4[0].SetBigNumber(Num) then Exit;
  Result := True;
end;

function FP4SetBigNumbers(const FP4: TCnFP4; const Num0, Num1: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP4[0].SetBigNumber(Num0) then Exit;
  if not FP4[1].SetBigNumber(Num1) then Exit;
  Result := True;
end;

function FP4SetFP2(const FP4: TCnFP4; const FP2: TCnFP2): Boolean;
begin
  Result := False;
  if not FP4[1].SetZero then Exit;
  if FP2Copy(FP4[0], FP2) = nil then Exit;
  Result := True;
end;

function FP4Set2FP2S(const FP4: TCnFP4; const FP20, FP21: TCnFP2): Boolean;
begin
  Result := False;
  if FP2Copy(FP4[0], FP20) = nil then Exit;
  if FP2Copy(FP4[1], FP21) = nil then Exit;
  Result := True;
end;

function FP4SetHex(const FP4: TCnFP4; const S0, S1, S2, S3: string): Boolean;
begin
  Result := False;
  if not FP4[1].SetHex(S2, S3) then Exit;
  if not FP4[0].SetHex(S0, S1) then Exit;
  Result := True;
end;

function FP4ToString(const FP4: TCnFP4): string;
begin
  Result := FP4[1].ToString + CRLF + FP4[0].ToString;
end;

function FP4SetWord(const FP4: TCnFP4; Value: Cardinal): Boolean;
begin
  Result := False;
  if not FP4[1].SetZero then Exit;
  if not FP4[0].SetWord(Value) then Exit;
  Result := True;
end;

function FP4SetWords(const FP4: TCnFP4; Value0, Value1, Value2, Value3: Cardinal): Boolean;
begin
  Result := False;
  if not FP4[0].SetWords(Value0, Value1) then Exit;
  if not FP4[1].SetWords(Value2, Value3) then Exit;
  Result := True;
end;

function FP4Equal(const F1, F2: TCnFP4): Boolean;
begin
  Result := FP2Equal(F1[0], F2[0]) and FP2Equal(F1[1], F2[1]);
end;

function FP4Copy(const Dst, Src: TCnFP4): TCnFP4;
begin
  Result := nil;
  if FP2Copy(Dst[0], Src[0]) = nil then Exit;
  if FP2Copy(Dst[1], Src[1]) = nil then Exit;
  Result := Dst;
end;

function FP4Negate(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
begin
  Result := FP2Negate(Res[0], F[0], Prime) and FP2Negate(Res[1], F[1], Prime);
end;

function FP4Add(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
begin
  Result := FP2Add(Res[0], F1[0], F2[0], Prime) and FP2Add(Res[1], F1[1], F2[1], Prime);
end;

function FP4Sub(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
begin
  Result := FP2Sub(Res[0], F1[0], F2[0], Prime) and FP2Sub(Res[1], F1[1], F2[1], Prime);
end;

function FP4Mul(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
var
  T, R0, R1: TCnFP2;
begin
  Result := False;

  // r0 = a0 * b0 + a1 * b1 * u
  // r1 = a0 * b1 + a1 * b0
  T := nil;
  R0 := nil;
  R1 := nil;

  try
    T := FLocalFP2Pool.Obtain;
    R0 := FLocalFP2Pool.Obtain;
    R1 := FLocalFP2Pool.Obtain;

    if not FP2Mul(R0, F1[0], F2[0], Prime) then Exit;
    if not FP2MulU(T, F1[1], F2[1], Prime) then Exit;
    if not FP2Add(R0, R0, T, Prime) then Exit;

    if not FP2Mul(R1, F1[0], F2[1], Prime) then Exit;
    if not FP2Mul(T, F1[1], F2[0], Prime) then Exit;
    if not FP2Add(Res[1], R1, T, Prime) then Exit;

    if FP2Copy(Res[0], R0) = nil then Exit;
    Result := True;
  finally
    FLocalFP2Pool.Recycle(R1);
    FLocalFP2Pool.Recycle(R0);
    FLocalFP2Pool.Recycle(T);
  end;
end;

function FP4Mul3(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
var
  T: TCnFP4;
begin
  Result := False;
  T := FLocalFP4Pool.Obtain;
  try
    if not FP4Add(T, F, F, Prime) then Exit;
    if not FP4Add(Res, T, F, Prime) then Exit;
    Result := True;
  finally
    FLocalFP4Pool.Recycle(T);
  end;
end;

function FP4MulV(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
var
  T, R0, R1: TCnFP2;
begin
  Result := False;

  // r0 = a0 * b1 * u + a1 * b0 * u
  // r1 = a0 * b0 + a1 * b1 * u
  T := nil;
  R0 := nil;
  R1 := nil;

  try
    T := FLocalFP2Pool.Obtain;
    R0 := FLocalFP2Pool.Obtain;
    R1 := FLocalFP2Pool.Obtain;

    if not FP2MulU(R0, F1[0], F2[1], Prime) then Exit;
    if not FP2MulU(T, F1[1], F2[0], Prime) then Exit;
    if not FP2Add(R0, R0, T, Prime) then Exit;

    if not FP2Mul(R1, F1[0], F2[0], Prime) then Exit;
    if not FP2MulU(T, F1[1], F2[1], Prime) then Exit;
    if not FP2Add(Res[1], R1, T, Prime) then Exit;

    if FP2Copy(Res[0], R0) = nil then Exit;
    Result := True;
  finally
    FLocalFP2Pool.Recycle(R1);
    FLocalFP2Pool.Recycle(R0);
    FLocalFP2Pool.Recycle(T);
  end;
end;

function FP4Inverse(const Res: TCnFP4; const F: TCnFP4; Prime: TCnBigNumber): Boolean;
var
  R0, R1, K: TCnFP2;
begin
  Result := False;

  // k = (f1^2 * u - f0^2)^-1
  // r0 = -(f0 * k)
  // r1 = f1 * k
  K := nil;
  R0 := nil;
  R1 := nil;

  try
    K := FLocalFP2Pool.Obtain;
    R0 := FLocalFP2Pool.Obtain;
    R1 := FLocalFP2Pool.Obtain;

    if not FP2MulU(K, F[1], F[1], Prime) then Exit;
    if not FP2Mul(R0, F[0], F[0], Prime) then Exit;
    if not FP2Sub(K, K, R0, Prime) then Exit;
    if not FP2Inverse(K, K, Prime) then Exit;

    if not FP2Mul(R0, F[0], K, Prime) then Exit;
    if not FP2Negate(R0, R0, Prime) then Exit;

    if not FP2Mul(R1, F[1], K, Prime) then Exit;

    if FP2Copy(Res[0], R0) = nil then Exit;
    if FP2Copy(Res[1], R1) = nil then Exit;
    Result := True;
  finally
    FLocalFP2Pool.Recycle(R1);
    FLocalFP2Pool.Recycle(R0);
    FLocalFP2Pool.Recycle(K);
  end;
end;

function FP4Div(const Res: TCnFP4; const F1, F2: TCnFP4; Prime: TCnBigNumber): Boolean;
var
  Inv: TCnFP4;
begin
  Result := False;
  if F2.IsZero then
    raise EZeroDivide.Create(SDivByZero);

  if F1 = F2 then
  begin
    if not Res.SetOne then Exit;
    Result := True;
  end
  else
  begin
    Inv := FLocalFP4Pool.Obtain;
    try
      if not FP4Inverse(Inv, F2, Prime) then Exit;
      if not FP4Mul(Res, F1, Inv, Prime) then Exit;
    finally
      FLocalFP4Pool.Recycle(Inv);
    end;
  end;
end;

function FP4ToStream(FP4: TCnFP4; Stream: TStream): Integer;
begin
  Result := FP2ToStream(FP4[0], Stream) + FP2ToStream(FP4[1], Stream);
end;

// ===================== ʮ�����������ϵ��Ԫ�����㺯�� ========================

function FP12New: TCnFP12;
begin
  Result := TCnFP12.Create;
end;

procedure FP12Free(FP12: TCnFP12);
begin
  FP12.Free;
end;

function FP12IsZero(FP12: TCnFP12): Boolean;
begin
  Result := FP12[0].IsZero and FP12[1].IsZero and FP12[2].IsZero;
end;

function FP12IsOne(FP12: TCnFP12): Boolean;
begin
  Result := FP12[0].IsOne and FP12[1].IsZero and FP12[2].IsZero;
end;

function FP12SetZero(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetZero then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetOne(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetOne then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetU(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetU then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetV(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetV then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetW(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetZero then Exit;
  if not FP12[1].SetOne then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetWSqr(FP12: TCnFP12): Boolean;
begin
  Result := False;
  if not FP12[0].SetZero then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetOne then Exit;
  Result := True;
end;

function FP12SetBigNumber(const FP12: TCnFP12; const Num: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP12[0].SetBigNumber(Num) then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetBigNumbers(const FP12: TCnFP12; const Num0, Num1, Num2: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP12[0].SetBigNumber(Num0) then Exit;
  if not FP12[1].SetBigNumber(Num1) then Exit;
  if not FP12[2].SetBigNumber(Num2) then Exit;
  Result := True;
end;

function FP12SetFP4(const FP12: TCnFP12; const FP4: TCnFP4): Boolean;
begin
  Result := False;
  if FP4Copy(FP12[0], FP4) = nil then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12Set3FP4S(const FP12: TCnFP12; const FP40, FP41, FP42: TCnFP4): Boolean;
begin
  Result := False;
  if FP4Copy(FP12[0], FP40) = nil then Exit;
  if FP4Copy(FP12[1], FP41) = nil then Exit;
  if FP4Copy(FP12[2], FP42) = nil then Exit;
  Result := True;
end;

function FP12SetFP2(const FP12: TCnFP12; const FP2: TCnFP2): Boolean;
begin
  Result := False;
  if not FP4SetFP2(FP12[0], FP2) then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetHex(const FP12: TCnFP12; const S0, S1, S2, S3, S4, S5, S6, S7, S8,
  S9, S10, S11: string): Boolean;
begin
  Result := False;
  if not FP12[0].SetHex(S0, S1, S2, S3) then Exit;
  if not FP12[1].SetHex(S4, S5, S6, S7) then Exit;
  if not FP12[2].SetHex(S8, S9, S10, S11) then Exit;
  Result := True;
end;

function FP12ToString(const FP12: TCnFP12): string;
begin
  Result := FP12[2].ToString + CRLF + FP12[1].ToString + CRLF + FP12[0].ToString;
end;

function FP12SetWord(const FP12: TCnFP12; Value: Cardinal): Boolean;
begin
  Result := False;
  if not FP4SetWord(FP12[0], Value) then Exit;
  if not FP12[1].SetZero then Exit;
  if not FP12[2].SetZero then Exit;
  Result := True;
end;

function FP12SetWords(const FP12: TCnFP12; Value0, Value1, Value2, Value3, Value4,
  Value5, Value6, Value7, Value8, Value9, Value10, Value11: Cardinal): Boolean;
begin
  Result := False;
  if not FP12[0].SetWords(Value0, Value1, Value2, Value3) then Exit;
  if not FP12[1].SetWords(Value4, Value5, Value6, Value7) then Exit;
  if not FP12[2].SetWords(Value8, Value9, Value10, Value11) then Exit;
  Result := True;
end;

function FP12Equal(const F1, F2: TCnFP12): Boolean;
begin
  Result := FP4Equal(F1[0], F2[0]) and FP4Equal(F1[1], F2[1]) and FP4Equal(F1[2], F2[2]);
end;

function FP12Copy(const Dst, Src: TCnFP12): TCnFP12;
begin
  Result := nil;
  if FP4Copy(Dst[0], Src[0]) = nil then Exit;
  if FP4Copy(Dst[1], Src[1]) = nil then Exit;
  if FP4Copy(Dst[2], Src[2]) = nil then Exit;
  Result := Dst;
end;

function FP12Negate(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP4Negate(Res[0], F[0], Prime) then Exit;
  if not FP4Negate(Res[1], F[1], Prime) then Exit;
  if not FP4Negate(Res[2], F[2], Prime) then Exit;
  Result := True;
end;

function FP12Add(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP4Add(Res[0], F1[0], F2[0], Prime) then Exit;
  if not FP4Add(Res[1], F1[1], F2[1], Prime) then Exit;
  if not FP4Add(Res[2], F1[2], F2[2], Prime) then Exit;
  Result := True;
end;

function FP12Sub(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP4Sub(Res[0], F1[0], F2[0], Prime) then Exit;
  if not FP4Sub(Res[1], F1[1], F2[1], Prime) then Exit;
  if not FP4Sub(Res[2], F1[2], F2[2], Prime) then Exit;
  Result := True;
end;

function FP12Mul(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  T, R0, R1, R2: TCnFP4;
begin
  Result := False;

  // r0 = a0 * b0 + a1 * b2 * v + a2 * b1 * v
  // r1 = a0 * b1 + a1 * b0 + a2 * b2 *v
  // r2 = a0 * b2 + a1 * b1 + a2 * b0
  T := nil;
  R0 := nil;
  R1 := nil;
  R2 := nil;

  try
    T := FLocalFP4Pool.Obtain;
    R0 := FLocalFP4Pool.Obtain;
    R1 := FLocalFP4Pool.Obtain;
    R2 := FLocalFP4Pool.Obtain;

    if not FP4Mul(R0, F1[0], F2[0], Prime) then Exit;
    if not FP4MulV(T, F1[1], F2[2], Prime) then Exit;
    if not FP4Add(R0, R0, T, Prime) then Exit;
    if not FP4MulV(T, F1[2], F2[1], Prime) then Exit;
    if not FP4Add(R0, R0, T, Prime) then Exit;

    if not FP4Mul(R1, F1[0], F2[1], Prime) then Exit;
    if not FP4Mul(T, F1[1], F2[0], Prime) then Exit;
    if not FP4Add(R1, R1, T, Prime) then Exit;
    if not FP4MulV(T, F1[2], F2[2], Prime) then Exit;
    if not FP4Add(R1, R1, T, Prime) then Exit;

    if not FP4Mul(R2, F1[0], F2[2], Prime) then Exit;
    if not FP4Mul(T, F1[1], F2[1], Prime) then Exit;
    if not FP4Add(R2, R2, T, Prime) then Exit;
    if not FP4Mul(T, F1[2], F2[0], Prime) then Exit;
    if not FP4Add(R2, R2, T, Prime) then Exit;

    if FP4Copy(Res[0], R0) = nil then Exit;
    if FP4Copy(Res[1], R1) = nil then Exit;
    if FP4Copy(Res[2], R2) = nil then Exit;

    Result := True;
  finally
    FLocalFP4Pool.Recycle(R2);
    FLocalFP4Pool.Recycle(R1);
    FLocalFP4Pool.Recycle(R0);
    FLocalFP4Pool.Recycle(T);
  end;
end;

function FP12Mul3(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  T: TCnFP12;
begin
  Result := False;
  T := FLocalFP12Pool.Obtain;
  try
    if not FP12Add(T, F, F, Prime) then Exit;
    if not FP12Add(Res, T, F, Prime) then Exit;
    Result := True;
  finally
    FLocalFP12Pool.Recycle(T);
  end;
end;

function FP12Inverse(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  K, T, T0, T1, T2, T3: TCnFP4;
begin
  Result := False;

  if FP4IsZero(F[2]) then // �ֿ�����
  begin
    // k = (f0^3 + f1^3 * v)^-1
    // r2 = f1^2 * k
    // r1 = -(f0 * f1 * k)
    // r0 = f0^2 * k
    K := nil;
    T := nil;

    try
      K := FLocalFP4Pool.Obtain;
      T := FLocalFP4Pool.Obtain;

      if not FP4Mul(K, F[0], F[0], Prime) then Exit;
      if not FP4Mul(K, K, F[0], Prime) then Exit;
      if not FP4MulV(T, F[1], F[1], Prime) then Exit;
      if not FP4Mul(T, T, F[1], Prime) then Exit;
      if not FP4Add(K, K, T, Prime) then Exit;
      if not FP4Inverse(K, K, Prime) then Exit;

      if not FP4Mul(T, F[1], F[1], Prime) then Exit;
      if not FP4Mul(Res[2], T, K, Prime) then Exit;

      if not FP4Mul(T, F[0], F[1], Prime) then Exit;
      if not FP4Mul(T, T, K, Prime) then Exit;
      if not FP4Negate(Res[1], T, Prime) then Exit;

      if not FP4Mul(T, F[0], F[0], Prime) then Exit;
      if not FP4Mul(Res[0], T, K, Prime) then Exit;

      Result := True;
    finally
      FLocalFP4Pool.Recycle(T);
      FLocalFP4Pool.Recycle(K);
    end;
  end
  else
  begin
    T := nil;
    T0 := nil;
    T1 := nil;
    T2 := nil;
    T3 := nil;

    try
      T := FLocalFP4Pool.Obtain;
      T0 := FLocalFP4Pool.Obtain;
      T1 := FLocalFP4Pool.Obtain;
      T2 := FLocalFP4Pool.Obtain;
      T3 := FLocalFP4Pool.Obtain;

      // t0 = f1^2 - f0 * f2
      // t1 = f0 * f1 - f2^2 * v
      // t2 = f0^2 - f1 * f2 * v
      // t3 = f2 * (t1^2 - t0 * t2)^-1
      if not FP4Mul(T0, F[1], F[1], Prime) then Exit;
      if not FP4Mul(T1, F[0], F[2], Prime) then Exit;
      if not FP4Sub(T0, T0, T1, Prime) then Exit;

      if not FP4Mul(T1, F[0], F[1], Prime) then Exit;
      if not FP4MulV(T2, F[2], F[2], Prime) then Exit;
      if not FP4Sub(T1, T1, T2, Prime) then Exit;

      if not FP4Mul(T2, F[0], F[0], Prime) then Exit;
      if not FP4MulV(T3, F[1], F[2], Prime) then Exit;
      if not FP4Sub(T2, T2, T3, Prime) then Exit;

      if not FP4Mul(T3, T1, T1, Prime) then Exit;
      if not FP4Mul(T, T0, T2, Prime) then Exit;
      if not FP4Sub(T3, T3, T, Prime) then Exit;
      if not FP4Inverse(T3, T3, Prime) then Exit;
      if not FP4Mul(T3, F[2], T3, Prime) then Exit;

      // r0 = t2 * t3
      // r1 = -(t1 * t3)
      // r2 = t0 * t3
      if not FP4Mul(Res[0], T2, T3, Prime) then Exit;

      if not FP4Mul(Res[1], T1, T3, Prime) then Exit;
      if not FP4Negate(Res[1], Res[1], Prime) then Exit;

      if not FP4Mul(Res[2], T0, T3, Prime) then Exit;

      Result := True;
    finally
      FLocalFP4Pool.Recycle(T3);
      FLocalFP4Pool.Recycle(T2);
      FLocalFP4Pool.Recycle(T1);
      FLocalFP4Pool.Recycle(T0);
      FLocalFP4Pool.Recycle(T);
    end;
  end;
end;

function FP12Div(const Res: TCnFP12; const F1, F2: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  Inv: TCnFP12;
begin
  Result := False;
  if F2.IsZero then
    raise EZeroDivide.Create(SDivByZero);

  if F1 = F2 then
  begin
    if not Res.SetOne then Exit;
    Result := True;
  end
  else
  begin
    Inv := FLocalFP12Pool.Obtain;
    try
      if not FP12Inverse(Inv, F2, Prime) then Exit;
      if not FP12Mul(Res, F1, Inv, Prime) then Exit;
    finally
      FLocalFP12Pool.Recycle(Inv);
    end;
  end;
end;

function FP12Power(const Res: TCnFP12; const F: TCnFP12; Exponent: TCnBigNumber;
  Prime: TCnBigNumber): Boolean;
var
  I, N: Integer;
  T: TCnFP12;
begin
  Result := False;
  if Exponent.IsZero then
  begin
    if not Res.SetOne then Exit;
    Result := True;
    Exit;
  end
  else if Exponent.IsOne then
  begin
    if FP12Copy(Res, F) = nil then Exit;
    Result := True;
    Exit;
  end;

  N := Exponent.GetBitsCount;
  if Res = F then
    T := FLocalFP12Pool.Obtain
  else
    T := Res;

  if FP12Copy(T, F) = nil then Exit;

  try
    for I := N - 2 downto 0 do  // ָ�������� 6 �� 13 ��֤���ƺ��ǶԵ�
    begin
      if not FP12Mul(T, T, T, Prime) then Exit;
      if Exponent.IsBitSet(I) then
        if not FP12Mul(T, T, F, Prime) then Exit;
    end;

    if Res = F then
      if FP12Copy(Res, T) = nil then Exit;
    Result := True;
  finally
    if Res = F then
      FLocalFP12Pool.Recycle(T);
  end;
end;

function FP12ToStream(FP12: TCnFP12; Stream: TStream): Integer;
begin
  Result := FP4ToStream(FP12[0], Stream) + FP4ToStream(FP12[1], Stream)
    + FP4ToStream(FP12[2], Stream);
end;

// ===================== ��������ϵ�����Ԫ������㺯�� ========================

function FP2AffinePointNew: TCnFP2AffinePoint;
begin
  Result := TCnFP2AffinePoint.Create;
end;

procedure AffinePointFree(P: TCnFP2AffinePoint);
begin
  P.Free;
end;

function FP2AffinePointSetZero(P: TCnFP2AffinePoint): Boolean;
begin
  Result := False;
  if not P.X.SetZero then Exit;
  if not P.Y.SetZero then Exit;
  if not P.Z.SetZero then Exit;
  Result := True;
end;

function FP2AffinePointToString(const P: TCnFP2AffinePoint): string;
begin
  Result := 'X: ' + P.X.ToString + CRLF + 'Y: ' + P.Y.ToString + CRLF + 'Z: ' + P.Z.ToString;
end;

function FP2AffinePointEqual(const P1, P2: TCnFP2AffinePoint): Boolean;
begin
  Result := FP2Equal(P1.X, P2.X) and FP2Equal(P1.Y, P2.Y) and FP2Equal(P1.Z, P2.Z);
end;

function FP2AffinePointCopy(const Dst, Src: TCnFP2AffinePoint): TCnFP2AffinePoint;
begin
  Result := nil;
  if FP2Copy(Dst.X, Src.X) = nil then Exit;
  if FP2Copy(Dst.Y, Src.Y) = nil then Exit;
  if FP2Copy(Dst.Z, Src.Z) = nil then Exit;
  Result := Dst;
end;

function FP2AffinePointIsAtInfinity(const P: TCnFP2AffinePoint): Boolean;
begin
  Result := FP2IsZero(P.X) and FP2IsOne(P.Y) and FP2IsZero(P.Z);
end;

function FP2AffinePointSetToInfinity(const P: TCnFP2AffinePoint): Boolean;
begin
  Result := False;
  if not P.X.SetZero then Exit;
  if not P.Y.SetOne then Exit;
  if not P.Z.SetZero then Exit;
  Result := True;
end;

function FP2AffinePointGetCoordinates(const P: TCnFP2AffinePoint; const FP2X, FP2Y: TCnFP2): Boolean;
begin
  Result := False;
  if P.Z.IsOne then
  begin
    if FP2Copy(FP2X, P.X) = nil then Exit;
    if FP2Copy(FP2Y, P.Y) = nil then Exit;
    Result := True;
  end;
end;

function FP2AffinePointSetCoordinates(const P: TCnFP2AffinePoint; const FP2X, FP2Y: TCnFP2): Boolean;
begin
  Result := False;
  if FP2Copy(P.X, FP2X) = nil then Exit;
  if FP2Copy(P.Y, FP2Y) = nil then Exit;
  if not FP2SetOne(P.Z) then Exit;
  Result := True;
end;

function FP2AffinePointSetCoordinatesHex(const P: TCnFP2AffinePoint;
  const SX0, SX1, SY0, SY1: string): Boolean;
begin
  Result := False;
  if not FP2SetHex(P.X, SX0, SX1) then Exit;
  if not FP2SetHex(P.Y, SY0, SY1) then Exit;
  if not FP2SetOne(P.Z) then Exit;
  Result := True;
end;

function FP2AffinePointSetCoordinatesBigNumbers(const P: TCnFP2AffinePoint;
  const X0, X1, Y0, Y1: TCnBigNumber): Boolean;
begin
  Result := False;
  if not FP2SetBigNumbers(P.X, X0, X1) then Exit;
  if not FP2SetBigNumbers(P.Y, X1, Y1) then Exit;
  if not FP2SetOne(P.Z) then Exit;
  Result := True;
end;

function FP2AffinePointGetJacobianCoordinates(const P: TCnFP2AffinePoint;
  const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  X, Y: TCnFP2;
  W: TCnFP12;
begin
  Result := False;

  X := nil;
  Y := nil;
  W := nil;

  try
    X := FLocalFP2Pool.Obtain;
    Y := FLocalFP2Pool.Obtain;
    W := FLocalFP12Pool.Obtain;

    if not FP2AffinePointGetCoordinates(P, X, Y) then Exit;
    if not FP12SetFP2(FP12X, X) then Exit;
    if not FP12SetFP2(FP12Y, Y) then Exit;

    // x = x * w^-2
    if not FP12SetWSqr(W) then Exit;
    if not FP12Inverse(W, W, Prime) then Exit;
    if not FP12Mul(FP12X, FP12X, W, Prime) then Exit;

    // y = y * w^-3
    if not FP12SetV(W) then Exit;
    if not FP12Inverse(W, W, Prime) then Exit;
    if not FP12Mul(FP12Y, FP12Y, W, Prime) then Exit;

    Result := True;
  finally
    FLocalFP2Pool.Recycle(Y);
    FLocalFP2Pool.Recycle(X);
    FLocalFP12Pool.Recycle(W);
  end;
end;

function FP2AffinePointSetJacobianCoordinates(const P: TCnFP2AffinePoint;
  const FP12X, FP12Y: TCnFP12; Prime: TCnBigNumber): Boolean;
var
  TX, TY: TCnFP12;
begin
  Result := False;

  TX := nil;
  TY := nil;

  try
    TX := FLocalFP12Pool.Obtain;
    TY := FLocalFP12Pool.Obtain;

    if not FP12SetWSqr(TX) then Exit;
    if not FP12SetV(TY) then Exit;
    if not FP12Mul(TX, FP12X, TX, Prime) then Exit;
    if not FP12Mul(TY, FP12Y, TY, Prime) then Exit;

    if not FP2AffinePointSetCoordinates(P, TX[0][0], TY[0][0]) then Exit;
    Result := True;
  finally
    FLocalFP12Pool.Recycle(TY);
    FLocalFP12Pool.Recycle(TX);
  end;
end;

function FP2AffinePointIsOnCurve(const P: TCnFP2AffinePoint; Prime: TCnBigNumber): Boolean;
var
  X, Y, B, T: TCnFP2;
begin
  Result := False;

  X := nil;
  Y := nil;
  B := nil;
  T := nil;

  try
    X := FLocalFP2Pool.Obtain;
    Y := FLocalFP2Pool.Obtain;
    B := FLocalFP2Pool.Obtain;
    T := FLocalFP2Pool.Obtain;

    if not B[0].SetZero then Exit;
    if not B[1].SetWord(CN_SM9_ECC_B) then Exit;   // B �� 5

    if not FP2AffinePointGetCoordinates(P, X, Y) then Exit;

    // X^3 + 5 u
    if not FP2Mul(T, X, X, Prime) then Exit;
    if not FP2Mul(X, X, T, Prime) then Exit;
    if not FP2Add(X, X, B, Prime) then Exit;

    // Y^2
    if not FP2Mul(Y, Y, Y, Prime) then Exit;

    Result := FP2Equal(X, Y);
  finally
    FLocalFP2Pool.Recycle(T);
    FLocalFP2Pool.Recycle(B);
    FLocalFP2Pool.Recycle(Y);
    FLocalFP2Pool.Recycle(X);
  end;
end;

function FP2AffinePointNegate(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if FP2Copy(Res.X, P.X) = nil then Exit;
  if not FP2Negate(Res.Y, P.Y, Prime) then Exit;
  if FP2Copy(Res.Z, P.Z) = nil then Exit;
  Result := True; 
end;

function FP2AffinePointDouble(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
var
  L, T, X1, Y1, X2, Y2: TCnFP2;
begin
  Result := False;
  if P.IsAtInfinity then
  begin
    Result := Res.SetToInfinity;
    Exit;
  end;

  L := nil;
  T := nil;
  X1 := nil;
  Y1 := nil;
  X2 := nil;
  Y2 := nil;

  try
    L := FLocalFP2Pool.Obtain;
    T := FLocalFP2Pool.Obtain;
    X1 := FLocalFP2Pool.Obtain;
    Y1 := FLocalFP2Pool.Obtain;
    X2 := FLocalFP2Pool.Obtain;
    Y2 := FLocalFP2Pool.Obtain;

    if not FP2AffinePointGetCoordinates(P, X1, Y1) then Exit;

    // L := 3 * x1^2 / (2 * y1)
    if not FP2Mul(L, X1, X1, Prime) then Exit;
    if not FP2Mul3(L, L, Prime) then Exit;
    if not FP2Add(T, Y1, Y1, Prime) then Exit;
    if not FP2Inverse(T, T, Prime) then Exit;
    if not FP2Mul(L, L, T, Prime) then Exit;

    // X2 = L^2 - 2 * X1
    if not FP2Mul(X2, L, L, Prime) then Exit;
    if not FP2Add(T, X1, X1, Prime) then Exit;
    if not FP2Sub(X2, X2, T, Prime) then Exit;

    // Y2 = L * (X1 - X2) - Y1
    if not FP2Sub(Y2, X1, X2, Prime) then Exit;
    if not FP2Mul(Y2, L, Y2, Prime) then Exit;
    if not FP2Sub(Y2, Y2, Y1, Prime) then Exit;

    if not FP2AffinePointSetCoordinates(Res, X2, Y2) then Exit;

    Result := True;
  finally
    FLocalFP2Pool.Recycle(Y2);
    FLocalFP2Pool.Recycle(X2);
    FLocalFP2Pool.Recycle(Y1);
    FLocalFP2Pool.Recycle(X1);
    FLocalFP2Pool.Recycle(T);
    FLocalFP2Pool.Recycle(L);
  end;
end;

function FP2AffinePointAdd(const Res: TCnFP2AffinePoint; const P, Q: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
var
  X1, Y1, X2, Y2, X3, Y3, L, T: TCnFP2;
begin
  Result := False;

  if FP2AffinePointIsAtInfinity(P) then
    Result := FP2AffinePointCopy(Res, Q) <> nil
  else if FP2AffinePointIsAtInfinity(Q) then
    Result := FP2AffinePointCopy(Res, P) <> nil
  else if FP2AffinePointEqual(P, Q) then
    Result := FP2AffinePointDouble(P, Q, Prime)
  else
  begin
    T := nil;
    L := nil;
    X1 := nil;
    Y1 := nil;
    X2 := nil;
    Y2 := nil;
    X3 := nil;
    Y3 := nil;

    try
      T := FLocalFP2Pool.Obtain;
      L := FLocalFP2Pool.Obtain;
      X1 := FLocalFP2Pool.Obtain;
      Y1 := FLocalFP2Pool.Obtain;
      X2 := FLocalFP2Pool.Obtain;
      Y2 := FLocalFP2Pool.Obtain;
      X3 := FLocalFP2Pool.Obtain;
      Y3 := FLocalFP2Pool.Obtain;

      if not FP2AffinePointGetCoordinates(P, X1, Y1) then Exit;
      if not FP2AffinePointGetCoordinates(Q, X2, Y2) then Exit;
      if not FP2Add(T, Y1, Y2, Prime) then Exit;

      if T.IsZero and FP2Equal(X1, X2) then // ������
      begin
        Result := Res.SetToInfinity; // ��Ϊ 0
        Exit;
      end;

      // L = (Y2 - Y1)/(X2 - X1)
      if not FP2Sub(L, Y2, Y1, Prime) then Exit;
      if not FP2Sub(T, X2, X1, Prime) then Exit;
      if not FP2Inverse(T, T, Prime) then Exit;
      if not FP2Mul(L, L, T, Prime) then Exit;

      // X3 = L^2 - X1 - X2
      if not FP2Mul(X3, L, L, Prime) then Exit;
      if not FP2Sub(X3, X3, X1, Prime) then Exit;
      if not FP2Sub(X3, X3, X2, Prime) then Exit;

      // Y3 = L * (X1 - X3) - Y1
      if not FP2Sub(Y3, X1, X3, Prime) then Exit;
      if not FP2Mul(Y3, L, Y3, Prime) then Exit;
      if not FP2Sub(Y3, Y3, Y1, Prime) then Exit;

      Result := FP2AffinePointSetCoordinates(Res, X3, Y3);
    finally
      FLocalFP2Pool.Recycle(Y3);
      FLocalFP2Pool.Recycle(X3);
      FLocalFP2Pool.Recycle(Y2);
      FLocalFP2Pool.Recycle(X2);
      FLocalFP2Pool.Recycle(Y1);
      FLocalFP2Pool.Recycle(X1);
      FLocalFP2Pool.Recycle(L);
      FLocalFP2Pool.Recycle(T);
    end;
  end;
end;

function FP2AffinePointSub(const Res: TCnFP2AffinePoint; const P, Q: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
var
  T: TCnFP2AffinePoint;
begin
  Result := False;
  T := FLocalFP2AffinePointPool.Obtain;
  try
    if not FP2AffinePointNegate(T, Q, Prime) then Exit;
    if not FP2AffinePointAdd(Res, P, T, Prime) then Exit;
    Result := True;
  finally
    FLocalFP2AffinePointPool.Recycle(T);
  end;
end;

function FP2AffinePointMul(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Num: TCnBigNumber; Prime: TCnBigNumber): Boolean;
var
  I, N: Integer;
  T: TCnFP2AffinePoint;
begin
  Result := False;

  if Num.IsZero then
    Result := FP2AffinePointSetToInfinity(Res)
  else if Num.IsOne then
    Result := FP2AffinePointCopy(Res, P) <> nil
  else  // �˶��ڼӣ���ͬ���ݶ��ڳˣ����Ժ� Power �㷨����
  begin
    N := Num.GetBitsCount;
    if Res = P then
      T := FLocalFP2AffinePointPool.Obtain
    else
      T := Res;
        
    try
      FP2AffinePointCopy(T, P);
      for I := N - 2 downto 0 do
      begin
        if not FP2AffinePointDouble(T, T, Prime) then Exit;
        if Num.IsBitSet(I) then
          if not FP2AffinePointAdd(T, T, P, Prime) then Exit;
      end;

      if Res = P then
        if FP2AffinePointCopy(Res, T) = nil then Exit;
      Result := True;
    finally
      if Res = P then
        FLocalFP2AffinePointPool.Recycle(T);
    end;
  end;
end;

function FP2AffinePointFrobenius(const Res: TCnFP2AffinePoint; const P: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
var
  X, Y: TCnFP12;
begin
  Result := False;

  X := nil;
  Y := nil;

  try
    X := FLocalFP12Pool.Obtain;
    Y := FLocalFP12Pool.Obtain;

    if not FP2AffinePointGetJacobianCoordinates(P, X, Y, Prime) then Exit;
    if not FP12Power(X, X, Prime, Prime) then Exit;
    if not FP12Power(Y, Y, Prime, Prime) then Exit;
    if not FP2AffinePointSetJacobianCoordinates(Res, X, Y, Prime) then Exit;
    Result := True;
  finally
    FLocalFP12Pool.Recycle(Y);
    FLocalFP12Pool.Recycle(X);
  end;
end;

function FP2PointToString(const P: TCnFP2Point): string;
begin
  Result := 'X: ' + P.X.ToString + CRLF + 'Y: ' + P.Y.ToString;
end;

function FP2AffinePointToFP2Point(FP2P: TCnFP2Point; FP2AP: TCnFP2AffinePoint;
  Prime: TCnBigNumber): Boolean;
var
  V: TCnFP2;
begin
  // X := X/Z   Y := Y/Z
  Result := False;

  V := FLocalFP2Pool.Obtain;
  try
    if not FP2Inverse(V, FP2AP.Z, Prime) then Exit;
    if not FP2Mul(FP2P.X, FP2AP.X, V, Prime) then Exit;
    if not FP2Mul(FP2P.Y, FP2AP.Y, V, Prime) then Exit;
  finally
    FLocalFP2Pool.Recycle(V);
  end;
end;

function FP2PointToFP2AffinePoint(FP2AP: TCnFP2AffinePoint; FP2P: TCnFP2Point): Boolean;
begin
  Result := False;
  if FP2Copy(FP2AP.X, FP2P.X) = nil then Exit;
  if FP2Copy(FP2AP.Y, FP2P.Y) = nil then Exit;

  if FP2AP.X.IsZero and FP2AP.Y.IsZero then
    Result := FP2AP.Z.SetZero
  else
    Result := FP2AP.Z.SetOne;
end;

// ============================ ˫���ԶԼ��㺯�� ===============================

// ��һ������
function Tangent(const Res: TCnFP12; const T: TCnFP2AffinePoint;
  const XP, YP: TCnBigNumber; Prime: TCnBigNumber): Boolean;
var
  X, Y, XT, YT, L, Q: TCnFP12;
begin
  Result := False;

  X := nil;
  Y := nil;
  XT := nil;
  YT := nil;
  L := nil;
  Q := nil;

  try
    X := FLocalFP12Pool.Obtain;
    Y := FLocalFP12Pool.Obtain;
    XT := FLocalFP12Pool.Obtain;
    YT := FLocalFP12Pool.Obtain;
    L := FLocalFP12Pool.Obtain;
    Q := FLocalFP12Pool.Obtain;

    if not FP2AffinePointGetJacobianCoordinates(T, XT, YT, Prime) then Exit;

    if not FP12SetBigNumber(X, XP) then Exit;
    if not FP12SetBigNumber(Y, YP) then Exit;

    // L = (3 * YT^2)/(2 * YT)
    if not FP12Mul(L, XT, XT, Prime) then Exit;
    if not FP12Mul3(L, L, Prime) then Exit;
    if not FP12Add(Q, YT, YT, Prime) then Exit;
    if not FP12Inverse(Q, Q, Prime) then Exit;
    if not FP12Mul(L, L, Q, Prime) then Exit;

    // r = lambda * (x - xT) - y + yT
    if not FP12Sub(Res, X, XT, Prime) then Exit;
    if not FP12Mul(Res, L, Res, Prime) then Exit;
    if not FP12Sub(Res, Res, Y, Prime) then Exit;
    if not FP12Add(Res, Res, YT, Prime) then Exit;

    Result := True;
  finally
    FLocalFP12Pool.Recycle(Q);
    FLocalFP12Pool.Recycle(L);
    FLocalFP12Pool.Recycle(YT);
    FLocalFP12Pool.Recycle(XT);
    FLocalFP12Pool.Recycle(Y);
    FLocalFP12Pool.Recycle(X);
  end;
end;

// ���������
function Secant(const Res: TCnFP12; const T, Q: TCnFP2AffinePoint;
  const XP, YP: TCnBigNumber; Prime: TCnBigNumber): Boolean;
var
  X, Y, L, M, XT, YT, XQ, YQ: TCnFP12;
begin
  Result := False;

  X := nil;
  Y := nil;
  L := nil;
  M := nil;
  XT := nil;
  YT := nil;
  XQ := nil;
  YQ := nil;

  try
    X := FLocalFP12Pool.Obtain;
    Y := FLocalFP12Pool.Obtain;
    L := FLocalFP12Pool.Obtain;
    M := FLocalFP12Pool.Obtain;
    XT := FLocalFP12Pool.Obtain;
    YT := FLocalFP12Pool.Obtain;
    XQ := FLocalFP12Pool.Obtain;
    YQ := FLocalFP12Pool.Obtain;

    if not FP2AffinePointGetJacobianCoordinates(T, XT, YT, Prime) then Exit;
    if not FP2AffinePointGetJacobianCoordinates(Q, XQ, YQ, Prime) then Exit;

    if not FP12SetBigNumber(X, XP) then Exit;
    if not FP12SetBigNumber(Y, YP) then Exit;

    // L = (yT - yQ)/(xT - xQ)
    if not FP12Sub(L, YT, YQ, Prime) then Exit;
    if not FP12Sub(M, XT, XQ, Prime) then Exit;
    if not FP12Inverse(M, M, Prime) then Exit;
    if not FP12Mul(L, L, M, Prime) then Exit;

    // r = L * (x - xQ) - y + yQ
    if not FP12Sub(Res, X, XQ, Prime) then Exit;
    if not FP12Mul(Res, L, Res, Prime) then Exit;
    if not FP12Sub(Res, Res, Y, Prime) then Exit;
    if not FP12Add(Res, Res, YQ, Prime) then Exit;

    Result := True;
  finally
    FLocalFP12Pool.Recycle(YQ);
    FLocalFP12Pool.Recycle(XQ);
    FLocalFP12Pool.Recycle(YT);
    FLocalFP12Pool.Recycle(XT);
    FLocalFP12Pool.Recycle(M);
    FLocalFP12Pool.Recycle(L);
    FLocalFP12Pool.Recycle(Y);
    FLocalFP12Pool.Recycle(X);
  end;
end;

function FP12FastExp1(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if FP2Copy(Res[0][0], F[0][0]) = nil then Exit;
  if not FP2Negate(Res[0][1], F[0][1], Prime) then Exit;
  if not FP2Negate(Res[1][0], F[1][0], Prime) then Exit;
  if FP2Copy(Res[1][1], F[1][1]) = nil then Exit;
  if FP2Copy(Res[2][0], F[2][0]) = nil then Exit;
  if not FP2Negate(Res[2][1], F[2][1], Prime) then Exit;
  Result := True;
end;

function FP12FastExp2(const Res: TCnFP12; const F: TCnFP12; Prime: TCnBigNumber): Boolean;
begin
  Result := False;
  if FP2Copy(Res[0][0], F[0][0]) = nil then Exit;
  if not FP2Negate(Res[0][1], F[0][1], Prime) then Exit;
  if not FP2Mul(Res[1][0], F[1][0], FFP12FastExpPW20, Prime) then Exit;
  if not FP2Mul(Res[1][1], F[1][1], FFP12FastExpPW21, Prime) then Exit;
  if not FP2Mul(Res[2][0], F[2][0], FFP12FastExpPW22, Prime) then Exit;
  if not FP2Mul(Res[2][1], F[2][1], FFP12FastExpPW23, Prime) then Exit;
  Result := True;
end;

function FinalFastExp(const Res: TCnFP12; const F: TCnFP12; const K: TCnBigNumber;
  Prime: TCnBigNumber): Boolean;
var
  I, N: Integer;
  T, T0: TCnFP12;
begin
  Result := False;

  T := nil;
  T0 := nil;

  try
    T := FLocalFP12Pool.Obtain;
    T0 := FLocalFP12Pool.Obtain;

    if FP12Copy(T, F) = nil then Exit;
    // FP12Copy(T0, F);
    if not FP12Inverse(T0, T, Prime) then Exit;
    if not FP12FastExp1(T, T, Prime) then Exit;
    if not FP12Mul(T, T0, T, Prime) then Exit;
    if FP12Copy(T0, T) = nil then Exit;

    if not FP12FastExp2(T, T, Prime) then Exit;
    if not FP12Mul(T, T0, T, Prime) then Exit;
    if FP12Copy(T0, T) = nil then Exit;

    N := K.GetBitsCount;
    for I := N - 2 downto 0 do
    begin
      if not FP12Mul(T, T, T, Prime) then Exit;
      if K.IsBitSet(I) then
        if not FP12Mul(T, T, T0, Prime) then Exit;
    end;

    if FP12Copy(Res, T) = nil then Exit;
    Result := True;
  finally
    FLocalFP12Pool.Recycle(T0);
    FLocalFP12Pool.Recycle(T);
  end;
end;

function Rate(const F: TCnFP12; const Q: TCnFP2AffinePoint; const XP, YP: TCnBigNumber;
  const A: TCnBigNumber; const K: TCnBigNumber; Prime: TCnBigNumber): Boolean;
var
  I, N: Integer;
  T, Q1, Q2: TCnFP2AffinePoint;
  G: TCnFP12;
begin
  Result := False;

  T := nil;
  Q1 := nil;
  Q2 := nil;
  G := nil;

  try
    T := FLocalFP2AffinePointPool.Obtain;
    Q1 := FLocalFP2AffinePointPool.Obtain;
    Q2 := FLocalFP2AffinePointPool.Obtain;
    G := FLocalFP12Pool.Obtain;

    if not FP12SetOne(F) then Exit;
    if FP2AffinePointCopy(T, Q) = nil then Exit;
    N := A.GetBitsCount;

    for I := N - 2 downto 0 do
    begin
      if not Tangent(G, T, XP, YP, Prime) then Exit;
      if not FP12Mul(F, F, F, Prime) then Exit;
      if not FP12Mul(F, F, G, Prime) then Exit;

      if not FP2AffinePointDouble(T, T, Prime) then Exit;

      if A.IsBitSet(I) then
      begin
        if not Secant(G, T, Q, XP, YP, Prime) then Exit;
        if not FP12Mul(F, F, G, Prime) then Exit;
        if not FP2AffinePointAdd(T, T, Q, Prime) then Exit;
      end;
    end;

    if not FP2AffinePointFrobenius(Q1, Q, Prime) then Exit;

    if not FP2AffinePointFrobenius(Q2, Q, Prime) then Exit;
    if not FP2AffinePointFrobenius(Q2, Q2, Prime) then Exit;

    if not Secant(G, T, Q1, XP, YP, Prime) then Exit;
    if not FP12Mul(F, F, G, Prime) then Exit;

    if not FP2AffinePointAdd(T, T, Q1, Prime) then Exit;

    if not FP2AffinePointNegate(Q2, Q2, Prime) then Exit;
    if not Secant(G, T, Q2, XP, YP, Prime) then Exit;
    if not FP12Mul(F, F, G, Prime) then Exit;

    if not FP2AffinePointAdd(T, T, Q2, Prime) then Exit;

    if not FinalFastExp(F, F, K, Prime) then Exit;
    Result := True;
  finally
    FLocalFP12Pool.Recycle(G);
    FLocalFP2AffinePointPool.Recycle(Q2);
    FLocalFP2AffinePointPool.Recycle(Q1);
    FLocalFP2AffinePointPool.Recycle(T);
  end;
end;

function SM9RatePairing(const F: TCnFP12; const Q: TCnFP2AffinePoint; const P: TCnEccPoint): Boolean;
var
  XP, YP: TCnBigNumber; // P �����������
  AQ: TCnFP2AffinePoint;   // Q �����������
begin
  if P <> nil then
  begin
    XP := P.X;
    YP := P.Y;
  end
  else // ��� P �� nil����ʹ�� SM9 �����ߵ� G1 ��
  begin
    XP := FSM9G1P1X;
    YP := FSM9G1P1Y;
  end;

  if Q = nil then // ��� Q �� nil����ʹ�� SM9 ���ߵ� G2 ��
  begin
    AQ := FLocalFP2AffinePointPool.Obtain;
    AQ.SetCoordinatesBigNumbers(FSM9G2P2X0, FSM9G2P2X1, FSM9G2P2Y0, FSM9G2P2Y1);
  end
  else
    AQ := Q;

  // ���� R-ate �Ե�ֵ
  Result := Rate(F, AQ, XP, YP, FSM96TPlus2, FSM9FastExpP3, FSM9FiniteFieldSize);

  if Q = nil then
    FLocalFP2AffinePointPool.Recycle(AQ);
end;

{ TCnFP2 }

constructor TCnFP2.Create;
begin
  inherited;
  F0 := TCnBigNumber.Create;
  F1 := TCnBigNumber.Create;
end;

destructor TCnFP2.Destroy;
begin
  F1.Free;
  F0.Free;
  inherited;
end;

function TCnFP2.GetItems(Index: Integer): TCnBigNumber;
begin
  if Index = 0 then
    Result := F0
  else if Index = 1 then
    Result := F1
  else
    raise Exception.CreateFmt(SListIndexError, [Index]);
end;

function TCnFP2.IsOne: Boolean;
begin
  Result := FP2IsOne(Self);
end;

function TCnFP2.IsZero: Boolean;
begin
  Result := FP2IsZero(Self);
end;

function TCnFP2.SetBigNumber(const Num: TCnBigNumber): Boolean;
begin
  Result := FP2SetBigNumber(Self, Num);
end;

function TCnFP2.SetHex(const S0, S1: string): Boolean;
begin
  Result := FP2SetHex(Self, S0, S1);
end;

function TCnFP2.SetOne: Boolean;
begin
  Result := FP2SetOne(Self);
end;

function TCnFP2.SetU: Boolean;
begin
  Result := FP2SetU(Self);
end;

function TCnFP2.SetWord(Value: Cardinal): Boolean;
begin
  Result := FP2SetWord(Self, Value);
end;

function TCnFP2.SetWords(Value0, Value1: Cardinal): Boolean;
begin
  Result := FP2SetWords(Self, Value0, Value1);
end;

function TCnFP2.SetZero: Boolean;
begin
  Result := FP2SetZero(Self);
end;

function TCnFP2.ToString: string;
begin
  Result := FP2ToString(Self);
end;

{ TCnFP4 }

constructor TCnFP4.Create;
begin
  inherited;
  F0 := TCnFP2.Create;
  F1 := TCnFP2.Create;
end;

destructor TCnFP4.Destroy;
begin
  F1.Free;
  F0.Free;
  inherited;
end;

function TCnFP4.GetItems(Index: Integer): TCnFP2;
begin
  if Index = 0 then
    Result := F0
  else if Index = 1 then
    Result := F1
  else
    raise Exception.CreateFmt(SListIndexError, [Index]);
end;

function TCnFP4.IsOne: Boolean;
begin
  Result := FP4IsOne(Self);
end;

function TCnFP4.IsZero: Boolean;
begin
  Result := FP4IsZero(Self);
end;

function TCnFP4.SetBigNumber(const Num: TCnBigNumber): Boolean;
begin
  Result := FP4SetBigNumber(Self, Num);
end;

function TCnFP4.SetBigNumbers(const Num0, Num1: TCnBigNumber): Boolean;
begin
  Result := FP4SetBigNumbers(Self, Num0, Num1);
end;

function TCnFP4.SetHex(const S0, S1, S2, S3: string): Boolean;
begin
  Result := FP4SetHex(Self, S0, S1, S2, S3);
end;

function TCnFP4.SetOne: Boolean;
begin
  Result := FP4SetOne(Self);
end;

function TCnFP4.SetU: Boolean;
begin
  Result := FP4SetU(Self);
end;

function TCnFP4.SetV: Boolean;
begin
  Result := FP4SetV(Self);
end;

function TCnFP4.SetWord(Value: Cardinal): Boolean;
begin
  Result := FP4SetWord(Self, Value);
end;

function TCnFP4.SetWords(Value0, Value1, Value2,
  Value3: Cardinal): Boolean;
begin
  Result := FP4SetWords(Self, Value0, Value1, Value2, Value3);
end;

function TCnFP4.SetZero: Boolean;
begin
  Result := FP4SetZero(Self);
end;

function TCnFP4.ToString: string;
begin
  Result := FP4ToString(Self);
end;

{ TCnFP12 }

constructor TCnFP12.Create;
begin
  inherited;
  F0 := TCnFP4.Create;
  F1 := TCnFP4.Create;
  F2 := TCnFP4.Create;
end;

destructor TCnFP12.Destroy;
begin
  F2.Free;
  F1.Free;
  F0.Free;
  inherited;
end;

function TCnFP12.GetItems(Index: Integer): TCnFP4;
begin
  if Index = 0 then
    Result := F0
  else if Index = 1 then
    Result := F1
  else if Index = 2 then
    Result := F2
  else
    raise Exception.CreateFmt(SListIndexError, [Index]);
end;

function TCnFP12.IsOne: Boolean;
begin
  Result := FP12IsOne(Self);
end;

function TCnFP12.IsZero: Boolean;
begin
  Result := FP12IsZero(Self);
end;

function TCnFP12.SetBigNumber(const Num: TCnBigNumber): Boolean;
begin
  Result := FP12SetBigNumber(Self, Num);
end;

function TCnFP12.SetBigNumbers(const Num0, Num1, Num2: TCnBigNumber): Boolean;
begin
  Result := FP12SetBigNumbers(Self, Num0, Num1, Num2);
end;

function TCnFP12.SetHex(const S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10,
  S11: string): Boolean;
begin
  Result := FP12SetHex(Self, S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11);
end;

function TCnFP12.SetOne: Boolean;
begin
  Result := FP12SetOne(Self);
end;

function TCnFP12.SetU: Boolean;
begin
  Result := FP12SetU(Self);
end;

function TCnFP12.SetV: Boolean;
begin
  Result := FP12SetV(Self);
end;

function TCnFP12.SetW: Boolean;
begin
  Result := FP12SetW(Self);
end;

function TCnFP12.SetWord(Value: Cardinal): Boolean;
begin
  Result := FP12SetWord(Self, Value);
end;

function TCnFP12.SetWords(Value0, Value1, Value2, Value3, Value4, Value5,
  Value6, Value7, Value8, Value9, Value10, Value11: Cardinal): Boolean;
begin
  Result := FP12SetWords(Self, Value0, Value1, Value2, Value3, Value4, Value5,
    Value6, Value7, Value8, Value9, Value10, Value11);
end;

function TCnFP12.SetWSqr: Boolean;
begin
  Result := FP12SetWSqr(Self);
end;

function TCnFP12.SetZero: Boolean;
begin
  Result := FP12SetZero(Self);
end;

function TCnFP12.ToString: string;
begin
  Result := FP12ToString(Self);
end;

{ TCnFP2Pool }

function TCnFP2Pool.CreateObject: TObject;
begin
  Result := TCnFP2.Create;
end;

function TCnFP2Pool.Obtain: TCnFP2;
begin
  Result := TCnFP2(inherited Obtain);
  Result.SetZero;
end;

procedure TCnFP2Pool.Recycle(Num: TCnFP2);
begin
  inherited Recycle(Num);
end;

{ TCnFP4Pool }

function TCnFP4Pool.CreateObject: TObject;
begin
  Result := TCnFP4.Create;
end;

function TCnFP4Pool.Obtain: TCnFP4;
begin
  Result := TCnFP4(inherited Obtain);
  Result.SetZero;
end;

procedure TCnFP4Pool.Recycle(Num: TCnFP4);
begin
  inherited Recycle(Num);
end;

{ TCnFP12Pool }

function TCnFP12Pool.CreateObject: TObject;
begin
  Result := TCnFP12.Create;
end;

function TCnFP12Pool.Obtain: TCnFP12;
begin
  Result := TCnFP12(inherited Obtain);
  Result.SetZero;
end;

procedure TCnFP12Pool.Recycle(Num: TCnFP12);
begin
  inherited Recycle(Num);
end;

{ TCnFP2AffinePoint }

constructor TCnFP2AffinePoint.Create;
begin
  inherited;
  FX := TCnFP2.Create;
  FY := TCnFP2.Create;
  FZ := TCnFP2.Create;
end;

destructor TCnFP2AffinePoint.Destroy;
begin
  FZ.Free;
  FY.Free;
  FX.Free;
  inherited;
end;

function TCnFP2AffinePoint.GetCoordinatesFP2(const FP2X,
  FP2Y: TCnFP2): Boolean;
begin
  Result := FP2AffinePointGetCoordinates(Self, FP2X, FP2Y);
end;

function TCnFP2AffinePoint.GetJacobianCoordinatesFP12(const FP12X, FP12Y: TCnFP12;
  Prime: TCnBigNumber): Boolean;
begin
  Result := FP2AffinePointGetJacobianCoordinates(Self, FP12X, FP12Y, Prime);
end;

function TCnFP2AffinePoint.IsAtInfinity: Boolean;
begin
  Result := FP2AffinePointIsAtInfinity(Self);
end;

function TCnFP2AffinePoint.IsOnCurve(Prime: TCnBigNumber): Boolean;
begin
  Result := FP2AffinePointIsOnCurve(Self, Prime);
end;

function TCnFP2AffinePoint.SetCoordinatesBigNumbers(const X0, X1, Y0,
  Y1: TCnBigNumber): Boolean;
begin
  Result := FP2AffinePointSetCoordinatesBigNumbers(Self, X0, X1, Y0, Y1);
end;

function TCnFP2AffinePoint.SetCoordinatesFP2(const FP2X,
  FP2Y: TCnFP2): Boolean;
begin
  Result := FP2AffinePointSetCoordinates(Self, FP2X, FP2Y);
end;

function TCnFP2AffinePoint.SetCoordinatesHex(const SX0, SX1, SY0,
  SY1: string): Boolean;
begin
  Result := FP2AffinePointSetCoordinatesHex(Self, SX0, SX1, SY0, SY1);
end;

function TCnFP2AffinePoint.SetJacobianCoordinatesFP12(const FP12X, FP12Y: TCnFP12;
  Prime: TCnBigNumber): Boolean;
begin
  Result := FP2AffinePointSetJacobianCoordinates(Self, FP12X, FP12Y, Prime);
end;

function TCnFP2AffinePoint.SetToInfinity: Boolean;
begin
  Result := FP2AffinePointSetToInfinity(Self);
end;

procedure TCnFP2AffinePoint.SetZero;
begin
  FP2AffinePointSetZero(Self);
end;

function TCnFP2AffinePoint.ToString: string;
begin
  Result := FP2AffinePointToString(Self);
end;

{ TCnFP2AffinePointPool }

function TCnFP2AffinePointPool.CreateObject: TObject;
begin
  Result := TCnFP2AffinePoint.Create;
end;

function TCnFP2AffinePointPool.Obtain: TCnFP2AffinePoint;
begin
  Result := TCnFP2AffinePoint(inherited Obtain);
//  Result.SetZero;
end;

procedure TCnFP2AffinePointPool.Recycle(Num: TCnFP2AffinePoint);
begin
  inherited Recycle(Num);
end;

procedure InitSM9Consts;
begin
  FSM9FiniteFieldSize := TCnBigNumber.FromHex(CN_SM9_FINITE_FIELD);
  FSM9Order := TCnBigNumber.FromHex(CN_SM9_ORDER);
  FSM9G1P1X := TCnBigNumber.FromHex(CN_SM9_G1_P1X);
  FSM9G1P1Y := TCnBigNumber.FromHex(CN_SM9_G1_P1Y);
  FSM9G2P2X0 := TCnBigNumber.FromHex(CN_SM9_G2_P2X0);
  FSM9G2P2X1 := TCnBigNumber.FromHex(CN_SM9_G2_P2X1);
  FSM9G2P2Y0 := TCnBigNumber.FromHex(CN_SM9_G2_P2Y0);
  FSM9G2P2Y1 := TCnBigNumber.FromHex(CN_SM9_G2_P2Y1);
  FSM96TPlus2 := TCnBigNumber.FromHex(CN_SM9_6T_PLUS_2);
  FSM9FastExpP3 := TCnBigNumber.FromHex(CN_SM9_FAST_EXP_P3);
  FFP12FastExpPW20 := TCnBigNumber.FromHex(CN_SM9_FAST_EXP_PW20);
  FFP12FastExpPW21 := TCnBigNumber.FromHex(CN_SM9_FAST_EXP_PW21);
  FFP12FastExpPW22 := TCnBigNumber.FromHex(CN_SM9_FAST_EXP_PW22);
  FFP12FastExpPW23 := TCnBigNumber.FromHex(CN_SM9_FAST_EXP_PW23);
end;

procedure FreeSM9Consts;
begin
  FSM9FiniteFieldSize.Free;
  FSM9Order.Free;
  FSM9G1P1X.Free;
  FSM9G1P1Y.Free;
  FSM9G2P2X0.Free;
  FSM9G2P2X1.Free;
  FSM9G2P2Y0.Free;
  FSM9G2P2Y1.Free;
  FSM96TPlus2.Free;
  FSM9FastExpP3.Free;
  FFP12FastExpPW20.Free;
  FFP12FastExpPW21.Free;
  FFP12FastExpPW22.Free;
  FFP12FastExpPW23.Free;
end;

function CnSM9KGCGenerateSignatureMasterKey(SignatureMasterKey:
  TCnSM9SignatureMasterKey; SM9: TCnSM9): Boolean;
var
  C: Boolean;
  AP: TCnFP2AffinePoint;
begin
  C := SM9 = nil;
  if C then
    SM9 := TCnSM9.Create;

  AP := nil;
  try
    BigNumberRandRange(SignatureMasterKey.PrivateKey, SM9.Order);
    if SignatureMasterKey.PrivateKey.IsZero then
      SignatureMasterKey.PrivateKey.SetOne;

    AP := TCnFP2AffinePoint.Create;
    FP2PointToFP2AffinePoint(AP, SM9.Generator2);

    FP2AffinePointMul(AP, AP, SignatureMasterKey.PrivateKey, SM9.FiniteFieldSize);
    FP2AffinePointToFP2Point(SignatureMasterKey.PublicKey, AP, SM9.FiniteFieldSize);

    Result := True;
  finally
    AP.Free;
    if C then
      SM9.Free;
  end;
end;

function CnSM9KGCGenerateEncryptionMasterKey(EncryptionMasterKey:
  TCnSM9EncryptionMasterKey; SM9: TCnSM9): Boolean;
var
  C: Boolean;
begin
  C := SM9 = nil;
  if C then
    SM9 := TCnSM9.Create;

  try
    BigNumberRandRange(EncryptionMasterKey.PrivateKey, SM9.Order);
    if EncryptionMasterKey.PrivateKey.IsZero then
      EncryptionMasterKey.PrivateKey.SetOne;

    EncryptionMasterKey.PublicKey.Assign(SM9.Generator);
    SM9.MultiplePoint(EncryptionMasterKey.PrivateKey, EncryptionMasterKey.PublicKey);

    Result := True;
  finally
    if C then
      SM9.Free;
  end;
end;

function CnSM9KGCGenerateSignatureUserKey(SignatureMasterPrivateKey: TCnSM9SignatureMasterPrivateKey;
  const AUserID: AnsiString; OutSignatureUserKey: TCnSM9SignatureUserPrivateKey; SM9: TCnSM9): Boolean;
begin

end;

function CnSM9KGCGenerateEncryptionUserKey(EncryptionMasterKey: TCnSM9EncryptionUserPrivateKey;
  const AUserID: AnsiString; OutEncryptionUserKey: TCnSM9EncryptionUserPrivateKey; SM9: TCnSM9): Boolean;
begin

end;

function SM9Hash(const Res: TCnBigNumber; Prefix: Byte; Data: Pointer; DataLen: Integer;
  N: TCnBigNumber): Boolean;
var
  CT, SCT, HLen: LongWord;
  I, CeilLen: Integer;
  IsInt: Boolean;
  DArr, Ha: array of Byte; // Ha �� HLen Bits
  SM3D: TSM3Digest;
  BH, BN: TCnBigNumber;

  function SwapLongWord(Value: LongWord): LongWord;
  begin
    Result := ((Value and $000000FF) shl 24) or ((Value and $0000FF00) shl 8)
      or ((Value and $00FF0000) shr 8) or ((Value and $FF000000) shr 24);
  end;

begin
  Result := False;
  if (Data = nil) or (DataLen <= 0) then
    Exit;

  DArr := nil;
  Ha := nil;
  BH := nil;
  BN := nil;

  // �� N �� 256 Bits ʱ

  try
    CT := 1;
    HLen := ((N.GetBitsCount * 5 + 31) div 32);
    HLen := 8 * HLen;
    // HLen ��һ�� Bits ����������� Ha �ı��س��ȣ������� SM9 ��Ӧ���ܱ� 8 ����Ҳ���Ƿ������ֽ���
    // N = 256 Bits ʱ HLen = 320

    IsInt := HLen mod CN_SM3_DIGEST_BITS = 0;
    CeilLen := (HLen + CN_SM3_DIGEST_BITS - 1) div CN_SM3_DIGEST_BITS;

    // CeilLen = 2��FloorLen = 1

    SetLength(DArr, DataLen + SizeOf(Byte) + SizeOf(LongWord)); // 1 Byte Prefix + 4 Byte Cardinal CT
    DArr[0] := Prefix;
    Move(Data^, DArr[1], DataLen);

    SetLength(Ha, HLen div 8);

    for I := 1 to CeilLen do
    begin
      SCT := SwapLongWord(CT);  // ��Ȼ�ĵ���û˵����Ҫ����һ��
      Move(SCT, DArr[DataLen + 1], SizeOf(LongWord));
      SM3D := SM3(@DArr[0], Length(DArr));

      if (I = CeilLen) and not IsInt then
      begin
        // �����һ����������ʱֻ�ƶ�һ����
        Move(SM3D[0], Ha[(I - 1) * SizeOf(TSM3Digest)], (HLen mod CN_SM3_DIGEST_BITS) div 8);
      end
      else
        Move(SM3D[0], Ha[(I - 1) * SizeOf(TSM3Digest)], SizeOf(TSM3Digest));

      Inc(CT);
    end;

    BN := BigNumberDuplicate(N);
    BN.SubWord(1);

    BH := TCnBigNumber.FromBinary(PAnsiChar(@Ha[0]), Length(Ha));
    Result := BigNumberNonNegativeMod(Res, BH, BN);
    Res.AddWord(1);
  finally
    BN.Free;
    BH.Free;
    SetLength(Ha, 0);
    SetLength(DArr, 0);
  end;
end;

function CnSM9Hash1(const Res: TCnBigNumber; Data: Pointer; DataLen: Integer;
  N: TCnBigNumber): Boolean;
begin
  Result := SM9Hash(Res, CN_SM9_HASH_PREFIX_1, Data, DataLen, N);
end;

function CnSM9Hash2(const Res: TCnBigNumber; Data: Pointer; DataLen: Integer;
  N: TCnBigNumber): Boolean;
begin
  Result := SM9Hash(Res, CN_SM9_HASH_PREFIX_2, Data, DataLen, N);
end;

{ TCnSM9EncryptionMasterKey }

constructor TCnSM9EncryptionMasterKey.Create;
begin
  inherited;
  FPrivateKey := TCnSM9EncryptionMasterPrivateKey.Create;
  FPublicKey := TCnSm9EncryptionMasterPublicKey.Create;
end;

destructor TCnSM9EncryptionMasterKey.Destroy;
begin
  FPublicKey.Free;
  FPrivateKey.Free;
  inherited;
end;

{ TCnSM9SignatureMasterKey }

constructor TCnSM9SignatureMasterKey.Create;
begin
  inherited;
  FPrivateKey := TCnSM9SignatureMasterPrivateKey.Create;
  FPublicKey := TCnSM9SignatureMasterPublicKey.Create;
end;

destructor TCnSM9SignatureMasterKey.Destroy;
begin
  FPublicKey.Free;
  FPrivateKey.Free;
  inherited;
end;

{ TCnFP2Point }

procedure TCnFP2Point.Assign(Source: TPersistent);
begin
  if Source is TCnFP2Point then
  begin
    FP2Copy(FX, (Source as TCnFP2Point).X);
    FP2Copy(FY, (Source as TCnFP2Point).Y);
  end
  else
    inherited;
end;

constructor TCnFP2Point.Create;
begin
  inherited;
  FX := TCnFP2.Create;
  FY := TCnFP2.Create;
end;

destructor TCnFP2Point.Destroy;
begin
  FY.Free;
  FX.Free;
  inherited;
end;

function TCnFP2Point.ToString: string;
begin
  Result := FP2PointToString(Self);
end;

{ TCnSM9 }

constructor TCnSM9.Create;
begin
  inherited Create(ctSM9Bn256v1);
  FGenerator2 := TCnFP2Point.Create;

  FGenerator2.X.SetHex(CN_SM9_G2_P2X0, CN_SM9_G2_P2X1);
  FGenerator2.Y.SetHex(CN_SM9_G2_P2Y0, CN_SM9_G2_P2Y1);
end;

destructor TCnSM9.Destroy;
begin
  FGenerator2.Free;
  inherited;
end;

initialization
  FLocalBigNumberPool := TCnBigNumberPool.Create;
  FLocalFP2Pool := TCnFP2Pool.Create;
  FLocalFP4Pool := TCnFP4Pool.Create;
  FLocalFP12Pool := TCnFP12Pool.Create;
  FLocalFP2AffinePointPool := TCnFP2AffinePointPool.Create;

  InitSM9Consts;

finalization
  FLocalFP2AffinePointPool.Free;
  FLocalFP12Pool.Free;
  FLocalFP4Pool.Free;
  FLocalFP2Pool.Free;
  FLocalBigNumberPool.Free;

  FreeSM9Consts;

end.