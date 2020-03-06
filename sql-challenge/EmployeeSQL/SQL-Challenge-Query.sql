/*Query Join Employees table to Salaries table, then query for employee number, 
last name, first name, gender, and salary 
*/
--Select last name, first name, gender, and salary--
SELECT A.emp_no, A.last_name,A.first_name,A.gender,concat('$',CAST(B.salary AS float(2))) AS "Salary"
FROM Employees A
JOIN Salaries B 
ON A.emp_no = B.emp_no;

--New Query--
--SELECT employee number,last name, first name and hire date where the hire date equals 1986--
SELECT emp_no,last_name,first_name,hire_date

FROM Employees 

WHERE DATE_PART('year',CAST(hire_date as date)) = 1986

ORDER BY HIRE_DATE;

--New Query--
/*List the manager of each department with the following information: department number, 
department name, the manager's employee number, last name, first name, and start and end employment dates.*/

SELECT A.dept_no,A.dept_name,B.emp_no,last_name,first_name,hire_date AS"Start Date",
CASE
	WHEN cast(to_date as DATE) = cast('9999-01-01' AS DATE) THEN 'Still Employeed'
	ELSE CAST(to_date AS VARCHAR)
END AS "End Date"

FROM "Departments" A
JOIN dept_manager B
	ON A.dept_no = B.dept_no
JOIN employees C	
	ON B.emp_no = C.emp_no
	
	ORDER BY to_date DESC;
	
--New Query--
--List the department of each employee with the following information: employee number, last name, first name, and department name.
SELECT A.emp_no,A.last_name,A.first_name,C.dept_name

FROM employees A
JOIN dept_emp B
	ON A.emp_no = B.emp_no
JOIN "Departments" C	
	ON B.dept_no = C.dept_no
	

ORDER BY dept_name,emp_no;

--New Query--
--List all employees whose first name is "Hercules" and last names begin with "B."

SELECT * 
FROM Employees
WHERE first_name = 'Hercules' AND SUBSTRING(last_name, 1, 1) = 'B'

ORDER BY last_name;

--New Query--
--List all employees in the Sales department, including their employee number, last name, first name, and department name.
SELECT A.emp_no,A.last_name,A.first_name,C.dept_name

FROM employees A
JOIN dept_emp B
	ON A.emp_no = B.emp_no
JOIN "Departments" C	
	ON B.dept_no = C.dept_no
	
WHERE c.dept_no = 'd007'

ORDER BY emp_no;

--New Query--
--List all employees in the Sales and Development departments, including their employee number, last name, first name, and department name.
SELECT A.emp_no,A.last_name,A.first_name,C.dept_name

FROM employees A
JOIN dept_emp B
	ON A.emp_no = B.emp_no
JOIN "Departments" C	
	ON B.dept_no = C.dept_no
	
WHERE c.dept_no in ('d007','d005')

ORDER BY dept_name,emp_no;

--New Query--
--In descending order, list the frequency count of employee last names, i.e., how many employees share each last name.

SELECT LAST_NAME,COUNT(LAST_NAME) AS "Count of Last Name" 
FROM Employees 
GROUP BY LAST_NAME 
ORDER BY "Count of Last Name";













