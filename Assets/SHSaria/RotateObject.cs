using UnityEngine;

public class RotateObjectsController : MonoBehaviour
{
    // 需要旋转的对象
    public GameObject object1;
    public GameObject object2;
    // 旋转速度
    public float rotationSpeed = 100f;
    // 控制每个对象的旋转状态
    private bool isRotatingObject1 = false;
    private bool isRotatingObject2 = false;
    // 记录每个对象的初始角度
    private Quaternion originalRotationObject1;
    private Quaternion originalRotationObject2;

    void Start()
    {
        // 记录每个对象的初始角度
        if (object1 != null)
        {
            originalRotationObject1 = object1.transform.rotation;
        }

        if (object2 != null)
        {
            originalRotationObject2 = object2.transform.rotation;
        }
    }

    // 通过传递参数来区分哪个按钮被点击
    public void OnButtonClick(int objectNumber)
    {
        if (objectNumber == 1)
        {
            if (isRotatingObject1)
            {
                isRotatingObject1 = false;
                object1.transform.rotation = originalRotationObject1;
            }
            else
            {
                isRotatingObject1 = true;
            }
        }
        else if (objectNumber == 2)
        {
            if (isRotatingObject2)
            {
                isRotatingObject2 = false;
                object2.transform.rotation = originalRotationObject2;
            }
            else
            {
                isRotatingObject2 = true;
            }
        }
    }

    void Update()
    {
        if (isRotatingObject1 && object1 != null)
        {
            object1.transform.Rotate(0, rotationSpeed * Time.deltaTime, 0);
        }

        if (isRotatingObject2 && object2 != null)
        {
            object2.transform.Rotate(0, rotationSpeed * Time.deltaTime, 0);
        }
    }
}
