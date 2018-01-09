#include<opencv2/opencv.hpp>

cv::Mat1b opencvHomog(cv::Mat1b img, cv::Mat_<double> homog)
{
  cv::Mat1b homogImg = img.clone();
  cv::warpPerspective(homogImg, homogImg, homog, homogImg.size(),16);
  return homogImg;
  
}


cv::Mat1b myHomog(cv::Mat1b img, cv::Mat_<double> homog)
{
  cv::Mat1b homogImg = img.clone();
  int newX, newY = 0;
  for (int i = 0; i < img.rows; i++)
    {
      for (int j = 0; j < img.cols; j++)
	{
	  newX = homog(0,0)*j + homog(0,1)*i + homog(0,2);
	  newY = homog(1,0)*j + homog(1,1)*i + homog(1,2);
	  homogImg[i][j] = (newX > img.cols-1 || newY > img.rows-1) ? 0 : img[newY][newX];
	}
    }
  return homogImg;
}
int main(int argc, char* argv[])
{

  int myHomogFlag = atoi(argv[1]);
  cv::Mat1b teste = cv::imread("2001.jpeg", CV_LOAD_IMAGE_GRAYSCALE);

  cv::Mat_<double> homogMatrix(3,3);
  homogMatrix(0,0) = 0.707;
  homogMatrix(0,1) = -0.707;
  homogMatrix(0,2) = 280;
  homogMatrix(1,0) = 0.707;
  homogMatrix(1,1) = 0.707;
  homogMatrix(1,2) = 0;
  homogMatrix(2,0) = 0;
  homogMatrix(2,1) = 0;
  homogMatrix(2,2) = 1;

  if (myHomogFlag) teste = opencvHomog(teste, homogMatrix);
  else teste = myHomog(teste, homogMatrix);

  
  //  cv::imshow("teste", teste);
  // cv::waitKey();

}
