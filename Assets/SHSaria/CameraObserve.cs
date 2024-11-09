using UnityEngine;
 
public class CameraObserve : MonoBehaviour
{
    public static CameraObserve Instance;
 
    /// <summary>
    /// 是否可以旋转
    /// </summary>
    public bool CanMove = false;
 
    /// <summary>
    /// 旋转目标
    /// </summary>
    public Transform Target;
 
    /// <summary>
    /// Mouse X速度
    /// </summary>
    public float XSpeed = 200;
 
    /// <summary>
    /// Mouse Y速度
    /// </summary>
    public float YSpeed = 200;
 
    /// <summary>
    /// Mouse ScrollWheel速度
    /// </summary>
    public float MSpeed = 10;
 
    /// <summary>
    /// Zoom速度
    /// </summary>
    public float ZSpeed = 0.04f;
 
    /// <summary>
    /// Y轴限制最小角度
    /// </summary>
    public float yMinLimit = -50;
 
    /// <summary>
    /// Y轴限制最大角度
    /// </summary>
    public float YMaxLimit = 50;
 
    /// <summary>
    /// 摄像机距离目标的距离
    /// </summary>
    public float CurrentDistance = 7;
 
    /// <summary>
    /// 限制最小距离
    /// </summary>
    public float MinDistance = 2;
 
    /// <summary>
    /// 限制最大距离
    /// </summary>
    public float MaxDistance = 30;
 
    /// <summary>
    /// 是否需要阻尼
    /// </summary>
    public bool IsDamping = true;
 
    /// <summary>
    /// 阻尼值
    /// </summary>
    public float Damping = 5.0f;
 
    /// <summary>
    /// 当前角度X
    /// </summary>
    private float CurrentAngleX = 0.0f;
 
    /// <summary>
    /// 当前角度Y
    /// </summary>
    private float CurrentAngleY = 0.0f;
 
    /// <summary>
    /// 当前位置X
    /// </summary>
    private float CurrentPosX = 0;
 
    /// <summary>
    /// 当前位置Y
    /// </summary>
    private float CurrentPosY = 0;
 
    /// <summary>
    /// 是否允许平移拖动
    /// </summary>
    public bool IsZoom = false;
 
    private void Awake()
    {
        Instance = this;
    }
    // Use this for initialization
    void Start()
    {
        InitNum();
    }
 
    /// <summary>
    /// 数值初始化
    /// </summary>
    private void InitNum()
    {
        Vector3 angles = transform.eulerAngles;
        CurrentAngleX = angles.y;
        CurrentAngleY = angles.x;
 
        CurrentPosX = transform.position.x;
        CurrentPosY = transform.position.y;
    }
 
 
    // Update is called once per frame
    void LateUpdate()
    {
        if (Target != null && CanMove)
        {
            if (Input.GetMouseButton(0))
            {
                CurrentAngleX += Input.GetAxis("Mouse X") * XSpeed * Time.deltaTime;
                CurrentAngleY -= Input.GetAxis("Mouse Y") * YSpeed * Time.deltaTime;
 
                CurrentAngleY = ClampAngle(CurrentAngleY, yMinLimit, YMaxLimit);
            }
 
            if (Input.GetMouseButton(2) && IsZoom)
            {
                CurrentPosX -= Input.GetAxis("Mouse X") * ZSpeed;
                CurrentPosY -= Input.GetAxis("Mouse Y") * ZSpeed;
            }
 
            CurrentDistance -= Input.GetAxis("Mouse ScrollWheel") * MSpeed;
            CurrentDistance = Mathf.Clamp(CurrentDistance, MinDistance, MaxDistance);
 
            Quaternion rotation = Quaternion.Euler(CurrentAngleY, CurrentAngleX, 0.0f);
            Vector3 disVector = new Vector3(CurrentPosX, CurrentPosY, -CurrentDistance);
            Vector3 position = rotation * disVector + Target.position;
 
 
            if (IsDamping)
            {
                transform.rotation = Quaternion.Lerp(transform.rotation, rotation, Time.deltaTime * Damping);
                transform.position = Vector3.Lerp(transform.position, position, Time.deltaTime * Damping);
            }
            else
            {
                transform.rotation = rotation;
                transform.position = position;
            }
        }
    }
 
    /// <summary>
    /// 设置Target
    /// </summary>
    /// <param name="tempTarget"></param>
    public void SetTarget(GameObject tempTarget)
    {
        ResetCamera();
        Target = tempTarget.transform;
    }
 
    /// <summary>
    /// 初始化摄像机
    /// </summary>
    public void ResetCamera()
    {
        CurrentAngleX = 0;
        CurrentAngleY = 0;
 
        CurrentPosX = transform.position.x;
        CurrentPosY = transform.position.y;
 
        transform.localPosition = new Vector3(0, 0, -7);
        CurrentDistance = 7;
        transform.localEulerAngles = new Vector3(0, 0, 0);
        InitNum();
        CanMove = true;
    }
 
    /// <summary>
    /// 角度转换
    /// </summary>
    /// <param name="angle"></param>
    /// <param name="min"></param>
    /// <param name="max"></param>
    /// <returns></returns>
    public static float ClampAngle(float angle, float min, float max)
    {
        if (angle < -360)
            angle += 360;
        if (angle > 360)
            angle -= 360;
        return Mathf.Clamp(angle, min, max);
    }
}