#python 2.7.12

print "Hello, world!"

a = -float(1.0/9);
kernel = [[a,a,a], [a,a,a], [a,a,a]];
data = [[10,10,10], [10,20,10], [10,20,10]];

sum = 0;

for i in range(0,len(kernel)):
    for j in range(0, len(kernel[0])):
        sum = sum + kernel[i][j]*data[i][j];

print(kernel)
print sum

t = 0.1111111 * 2**8
print t
